/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipAutomation
import AirshipCore

final class InAppMessageAutomationPreparerTest: XCTestCase {

    private let displayCoordinatorManager: TestDisplayCoordinatorManager = TestDisplayCoordinatorManager()
    private let displayAdapterFactory: TestDisplayAdapterFactory = TestDisplayAdapterFactory()
    private let assetManager: TestAssetManager = TestAssetManager()
    private let analyticsFactory: TestAnalyticsFactory = TestAnalyticsFactory()
    private let analytics: TestInAppMessageAnalytics = TestInAppMessageAnalytics()
    private let actionRunnerFactory: TestInAppActionRunnerFactory = TestInAppActionRunnerFactory()

    private var preparer: InAppMessageAutomationPreparer!
    private let message: InAppMessage = InAppMessage(
        name: "",
        displayContent: .banner(.init(media: .init(url: "some-url", type: .image)))
    )

    private let preparedScheduleInfo: PreparedScheduleInfo = PreparedScheduleInfo(
        scheduleID: UUID().uuidString,
        campaigns: "campigns",
        contactID: UUID().uuidString,
        experimentResult: nil,
        triggerSessionID: UUID().uuidString,
        priority: 0
    )

    override func setUp() async throws {
        await analyticsFactory.setOnMake { [analytics] _, _ in
            return analytics
        }
        self.preparer = InAppMessageAutomationPreparer(
            assetManager: assetManager,
            displayCoordinatorManager: displayCoordinatorManager,
            displayAdapterFactory: displayAdapterFactory,
            analyticsFactory: analyticsFactory,
            actionRunnerFactory: actionRunnerFactory
        )

        actionRunnerFactory.onMake = { _, _ in return TestInAppActionRunner() }
    }

    func testPrepare() async throws {
        let runner = TestInAppActionRunner()
        actionRunnerFactory.onMake = { _, _ in return runner }

        let cachedAssets = TestCachedAssets()
        await self.assetManager.setOnCache { [preparedScheduleInfo] identifier, assets in
            XCTAssertEqual(identifier, preparedScheduleInfo.scheduleID)
            XCTAssertEqual(["some-url"], assets)
            return cachedAssets
        }

        let displayCoordinator = await TestDisplayCoordinator()
        self.displayCoordinatorManager.onCoordinator = { [message] incoming in
            XCTAssertEqual(message, incoming)
            return displayCoordinator
        }

        let displayAdapter = await TestDisplayAdapter()
        self.displayAdapterFactory.onMake = { [message] args in
            XCTAssertEqual(message, args.message)
            let incomingAssets = args.assets as? TestCachedAssets
            XCTAssertTrue(incomingAssets === cachedAssets)
            return displayAdapter
        }

        guard case .prepared(let results) = try await self.preparer.prepare(data: message, preparedScheduleInfo: preparedScheduleInfo) else {
            return XCTFail("Expected .prepared result")
        }

        XCTAssertEqual(self.message, results.message)
        XCTAssertTrue(displayCoordinator === results.displayCoordinator)
        XCTAssertTrue(displayAdapter === (results.displayAdapter as? TestDisplayAdapter))
        XCTAssertTrue(runner === (results.actionRunner as? TestInAppActionRunner))
    }

    func testPrepareFailedAssets() async throws {
        let displayCoordinator = await TestDisplayCoordinator()
        let adapter = await TestDisplayAdapter()
        
        self.displayCoordinatorManager.onCoordinator = { _ in
            return displayCoordinator
        }

        self.displayAdapterFactory.onMake = { _ in
            return adapter
        }

        await self.assetManager.setOnCache { identifier, assets in
            throw AirshipErrors.error("failed")
        }

        do {
            _ = try await self.preparer.prepare(data: message, preparedScheduleInfo: preparedScheduleInfo)
            XCTFail("should throw")
        } catch {}
    }

    func testPrepareFailedAdapter() async throws {
        let displayCoordinator = await TestDisplayCoordinator()
        self.displayCoordinatorManager.onCoordinator = { _ in
            return displayCoordinator
        }

        self.displayAdapterFactory.onMake = { _ in
            throw AirshipErrors.error("failed")
        }

        await self.assetManager.setOnCache { _, _ in
            return TestCachedAssets()
        }

        do {
            _ = try await self.preparer.prepare(data: message, preparedScheduleInfo: preparedScheduleInfo)
            XCTFail("should throw")
        } catch {}
    }

    func testPrepareIntermediateLayoutResolveFails_appDefined_cancels() async throws {
        // A broken layout JSON (not a valid AirshipLayoutWrapper) on an app-defined
        // schedule should return .cancel — the payload won't be updated by remote data.
        let badMessage = InAppMessage(
            name: "bad layout",
            displayContent: .airshipLayoutIntermediate(AirshipLayoutIntermediate(layoutJSON: .string("not a layout")))
        )
        let result = try await self.preparer.prepare(data: badMessage, preparedScheduleInfo: preparedScheduleInfo)
        guard case .cancel = result else { return XCTFail("Expected .cancel, got \(result)") }
    }

    func testPrepareIntermediateLayoutResolveFails_remoteData_skips() async throws {
        // A broken layout JSON on a remote-data schedule should return .skip so the
        // schedule goes back to idle and retries after the server pushes a fix.
        let badMessage = InAppMessage(
            name: "bad layout",
            displayContent: .airshipLayoutIntermediate(AirshipLayoutIntermediate(layoutJSON: .string("not a layout"))),
            source: .remoteData
        )
        let result = try await self.preparer.prepare(data: badMessage, preparedScheduleInfo: preparedScheduleInfo)
        guard case .skip = result else { return XCTFail("Expected .skip, got \(result)") }
    }

    func testCancelled() async throws {
        let scheduleID = UUID().uuidString
        await self.preparer.cancelled(scheduleID: scheduleID)

        let cleared = await self.assetManager.cleared
        XCTAssertEqual(cleared, [scheduleID])
    }

}

fileprivate final class TestDisplayCoordinatorManager: DisplayCoordinatorManagerProtocol, @unchecked Sendable {
    var displayInterval: TimeInterval = 0.0
    var onCoordinator: ((InAppMessage) -> DisplayCoordinator)?
    func displayCoordinator(message: InAppMessage) -> DisplayCoordinator {
        self.onCoordinator!(message)
    }
}

fileprivate final class TestDisplayAdapterFactory: DisplayAdapterFactoryProtocol, @unchecked Sendable {
    var onMake: ((DisplayAdapterArgs) throws -> DisplayAdapter)?

    func setAdapterFactoryBlock(forType: CustomDisplayAdapterType, factoryBlock: @escaping @Sendable (DisplayAdapterArgs) -> (any CustomDisplayAdapter)?) {

    }
    
    func makeAdapter(args: DisplayAdapterArgs) throws -> any DisplayAdapter {
        return try self.onMake!(args)
    }
}



final class TestInAppActionRunnerFactory: InAppActionRunnerFactoryProtocol, @unchecked Sendable {
    var onMake: ((InAppMessage, InAppMessageAnalyticsProtocol) -> InternalInAppActionRunner)?


    func makeRunner(message: InAppMessage, analytics: any InAppMessageAnalyticsProtocol) -> any InternalInAppActionRunner {
        return self.onMake!(message, analytics)
    }
}

