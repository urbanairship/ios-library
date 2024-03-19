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

    private var preparer: InAppMessageAutomationPreparer!
    private let message: InAppMessage = InAppMessage(
        name: "",
        displayContent: .banner(.init(media: .init(url: "some-url", type: .image)))
    )

    private let preparedScheduleInfo: PreparedScheduleInfo = PreparedScheduleInfo(
        scheduleID: UUID().uuidString,
        campaigns: .string("campigns"),
        contactID: UUID().uuidString,
        experimentResult: nil,
        triggerSessionID: UUID().uuidString
    )

    override func setUp() async throws {
        await analyticsFactory.setOnMake { [analytics] _, _ in
            return analytics
        }
        self.preparer = InAppMessageAutomationPreparer(
            assetManager: assetManager,
            displayCoordinatorManager: displayCoordinatorManager,
            displayAdapterFactory: displayAdapterFactory,
            analyticsFactory: analyticsFactory
        )
    }

    func testPrepare() async throws {
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

        let displayAdapter = TestDisplayAdapter()
        self.displayAdapterFactory.onMake = { [message] incomingMessage, incomingAssets in
            XCTAssertEqual(message, incomingMessage)
            let incomingAssets = incomingAssets as? TestCachedAssets
            XCTAssertTrue(incomingAssets === cachedAssets)
            return displayAdapter
        }

        let results = try await self.preparer.prepare(data: message, preparedScheduleInfo: preparedScheduleInfo)

        XCTAssertEqual(self.message, results.message)
        XCTAssertTrue(displayCoordinator === results.displayCoordinator)
        XCTAssertTrue(displayAdapter === (results.displayAdapter as? TestDisplayAdapter))
    }

    func testPrepareFailedAssets() async throws {
        let displayCoordinator = await TestDisplayCoordinator()
        self.displayCoordinatorManager.onCoordinator = { _ in
            return displayCoordinator
        }

        self.displayAdapterFactory.onMake = { _, _ in
            return TestDisplayAdapter()
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

        self.displayAdapterFactory.onMake = { _, _ in
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
    func setAdapterFactoryBlock(forType: CustomDisplayAdapterType, factoryBlock: @escaping @Sendable (InAppMessage, AirshipCachedAssetsProtocol) -> CustomDisplayAdapter?) {

    }
    var onMake: ((InAppMessage, AirshipCachedAssetsProtocol) throws -> DisplayAdapter)?
    func makeAdapter(message: InAppMessage, assets: AirshipCachedAssetsProtocol) throws -> DisplayAdapter {
        return try self.onMake!(message, assets)
    }
}

