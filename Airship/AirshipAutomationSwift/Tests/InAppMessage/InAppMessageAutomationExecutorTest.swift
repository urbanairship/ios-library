/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipAutomationSwift
import AirshipCore

final class InAppMessageAutomationExecutorTest: XCTestCase {

    private let sceneManager: TestSceneManager = TestSceneManager()
    private let assetManager: TestAssetManager = TestAssetManager()
    private let analyticsFactory: TestAnalyticsFactory = TestAnalyticsFactory()
    private let conditionsChangedNotifier: Notifier = Notifier()
   
    private let displayAdapter: TestDisplayAdapter = TestDisplayAdapter()
    private let actionRunner: TestActionRunner = TestActionRunner()


    private let preparedInfo: PreparedScheduleInfo = PreparedScheduleInfo(
        scheduleID: UUID().uuidString,
        productID: UUID().uuidString,
        campaigns: .string(UUID().uuidString),
        contactID: UUID().uuidString,
        reportingContext: .string(UUID().uuidString)
    )

    private var displayCoordinator: TestDisplayCoordinator!
    private var preparedData: PreparedInAppMessageData!
    private var executor: InAppMessageAutomationExecutor!

    override func setUp() async throws {
        self.displayCoordinator = await TestDisplayCoordinator()
        self.preparedData = PreparedInAppMessageData(
            message: InAppMessage(
                name: "",
                displayContent: .custom(.string("")),
                actions: .string("actions payload")
            ),
            displayAdapter: self.displayAdapter,
            displayCoordinator: self.displayCoordinator
        )

        self.executor = InAppMessageAutomationExecutor(
            sceneManager: sceneManager,
            assetManager: assetManager,
            analyticsFactory: analyticsFactory,
            conditionsChangedNotifier: conditionsChangedNotifier,
            actionRunner: actionRunner
        )
    }

    @MainActor
    func testIsReady() {
        self.displayAdapter.isReady = true
        self.displayCoordinator.isReady = true
        XCTAssertEqual(
            self.executor.isReady(data: preparedData, preparedScheduleInfo: preparedInfo),
            .ready
        )
    }

    @MainActor
    func testNotReadyAdapter() {
        self.displayAdapter.isReady = false
        self.displayCoordinator.isReady = true
        XCTAssertEqual(
            self.executor.isReady(data: preparedData, preparedScheduleInfo: preparedInfo),
            .notReady
        )
    }

    @MainActor
    func testNotReadyCoordinator() {
        self.displayAdapter.isReady = true
        self.displayCoordinator.isReady = false
        XCTAssertEqual(
            self.executor.isReady(data: preparedData, preparedScheduleInfo: preparedInfo),
            .notReady
        )
    }

    @MainActor
    func testIsReadyDelegate() {
        self.displayAdapter.isReady = true
        self.displayCoordinator.isReady = true

        let delegate = TestDisplayDelegate()
        delegate.onIsReady = { [preparedData, preparedInfo] message, scheduleID in
            XCTAssertEqual(message, preparedData!.message)
            XCTAssertEqual(scheduleID, preparedInfo.scheduleID)
            return true
        }
        self.executor.displayDelegate = delegate

        XCTAssertEqual(
            self.executor.isReady(data: preparedData, preparedScheduleInfo: preparedInfo),
            .ready
        )

        delegate.onIsReady = { [preparedData, preparedInfo] message, scheduleID in
            XCTAssertEqual(message, preparedData!.message)
            XCTAssertEqual(scheduleID, preparedInfo.scheduleID)
            return false
        }

        XCTAssertEqual(
            self.executor.isReady(data: preparedData, preparedScheduleInfo: preparedInfo),
            .notReady
        )
    }

    func testInterrupted() async throws {
        let schedule = AutomationSchedule(
            identifier: preparedInfo.scheduleID,
            triggers: [],
            data: .inAppMessage(preparedData.message)
        )

        let analytics = TestInAppMessageAnalytics()
        await self.analyticsFactory.setOnMake { _, _, _, _, _, _ in
            return analytics
        }


        await self.executor.interrupted(schedule: schedule, preparedScheduleInfo: preparedInfo)
        let cleared = await self.assetManager.cleared
        XCTAssertEqual([self.preparedInfo.scheduleID], cleared)
        XCTAssertEqual(analytics.events.first!.0.name, InAppResolutionEvent.interrupted().name)
    }

    @MainActor
    func testExecute() async throws  {
        let scene = TestScene()
        self.sceneManager.onScene = { [preparedData] message in
            XCTAssertEqual(message, preparedData!.message)
            return scene
        }


        let analytics = TestInAppMessageAnalytics()
        self.analyticsFactory.onMake = { [preparedData, preparedInfo] scheduleID, productID, contactID, message, campaigns, reportingContext in
            XCTAssertEqual(scheduleID, preparedInfo.scheduleID)
            XCTAssertEqual(preparedInfo.productID, productID)
            XCTAssertEqual(preparedInfo.contactID, contactID)
            XCTAssertEqual(campaigns, preparedInfo.campaigns)
            XCTAssertEqual(reportingContext, preparedInfo.reportingContext)
            XCTAssertEqual(message, preparedData!.message)
            return analytics
        }

        self.displayAdapter.onDisplay = { incomingScene, incomingAnalytics in
            XCTAssertTrue(scene === (incomingScene as? TestScene))
            XCTAssertTrue(analytics === (incomingAnalytics as? TestInAppMessageAnalytics))
            await incomingAnalytics.recordImpression()
            return .finished
        }

        XCTAssertEqual(0, analytics.impressionsRecored)
        let result =  try await self.executor.execute(data: preparedData, preparedScheduleInfo: preparedInfo)

        XCTAssertEqual(1, analytics.impressionsRecored)
        XCTAssertTrue(self.displayAdapter.displayed)
        XCTAssertEqual(result, .finished)
    }

    @MainActor
    func testExecuteInControlGroup() async throws  {
        let scene = TestScene()
        self.sceneManager.onScene = { [preparedData] message in
            XCTAssertEqual(message, preparedData!.message)
            return scene
        }

        let experimentResult = ExperimentResult(
            channelId: "some channel",
            contactId: "some contact",
            isMatch: true,
            reportingMetadata: []
        )
        var preparedInfo = preparedInfo
        preparedInfo.experimentResult = experimentResult

        let analytics = TestInAppMessageAnalytics()
        self.analyticsFactory.onMake = {  _, _, _, _, _, _ in
            return analytics
        }

        let result = try await self.executor.execute(data: preparedData, preparedScheduleInfo: preparedInfo)

        XCTAssertEqual(analytics.events.first!.0.name, InAppResolutionEvent.control(experimentResult: experimentResult).name)
        XCTAssertFalse(self.displayAdapter.displayed)
        XCTAssertEqual(result, .finished)
        XCTAssertNil(self.actionRunner.actions)
    }

    @MainActor
    func testExecuteDisplayAdapter() async throws  {
        let delegate = TestDisplayDelegate()
        self.executor.displayDelegate = delegate

        delegate.onWillDisplay = { [preparedData, preparedInfo] message, scheduleID in
            XCTAssertEqual(message, preparedData!.message)
            XCTAssertEqual(scheduleID, preparedInfo.scheduleID)
        }

        delegate.onFinishedDisplaying = { [preparedData, preparedInfo] message, scheduleID in
            XCTAssertEqual(message, preparedData!.message)
            XCTAssertEqual(scheduleID, preparedInfo.scheduleID)
        }

        self.sceneManager.onScene = { _ in
            return TestScene()
        }

        self.analyticsFactory.onMake = { _, _, _, _, _, _ in
            return TestInAppMessageAnalytics()
        }

        self.displayAdapter.onDisplay = { _, _ in
            XCTAssertTrue(delegate.onWillDisplayCalled)
            XCTAssertFalse(delegate.onFinishedDisplayingCalled)
            return .finished
        }

        let result = try await self.executor.execute(data: preparedData, preparedScheduleInfo: preparedInfo)
        XCTAssertTrue(delegate.onWillDisplayCalled)
        XCTAssertTrue(delegate.onWillDisplayCalled)
        XCTAssertTrue(self.displayAdapter.displayed)
        XCTAssertEqual(result, .finished)
    }

    @MainActor
    func testExecuteDisplayException() async throws  {
        let scene = TestScene()
        self.sceneManager.onScene = { [preparedData] message in
            XCTAssertEqual(message, preparedData!.message)
            return scene
        }

        let analytics = TestInAppMessageAnalytics()
        self.analyticsFactory.onMake = { [preparedData, preparedInfo] scheduleID, productID, contactID, message, campaigns, reportingContext in
            XCTAssertEqual(scheduleID, preparedInfo.scheduleID)
            XCTAssertEqual(productID, preparedInfo.productID)
            XCTAssertEqual(contactID, preparedInfo.contactID)
            XCTAssertEqual(campaigns, preparedInfo.campaigns)
            XCTAssertEqual(reportingContext, preparedInfo.reportingContext)
            XCTAssertEqual(message, preparedData!.message)
            return analytics
        }

        self.displayAdapter.onDisplay = { incomingScene, incomingAnalytics in
            throw AirshipErrors.error("Failed")
        }

        let result =  try await self.executor.execute(data: preparedData, preparedScheduleInfo: preparedInfo)

        XCTAssertTrue(self.displayAdapter.displayed)
        XCTAssertEqual(result, .retry)
        XCTAssertNil(self.actionRunner.actions)
    }

    @MainActor
    func testExecuteNoScene() async throws  {
        self.sceneManager.onScene = { _ in
            throw AirshipErrors.error("Fail")
        }

        self.analyticsFactory.onMake = { _, _, _, _, _, _ in
            return TestInAppMessageAnalytics()
        }

        self.displayAdapter.onDisplay = { _, _ in
            XCTFail()
            return .cancel
        }

        do {
            _ = try await self.executor.execute(data: preparedData, preparedScheduleInfo: preparedInfo)
            XCTFail("should throw")
        } catch {}

        XCTAssertNil(self.actionRunner.actions)
    }

    @MainActor
    func testExecuteCancel() async throws  {
        let scene = TestScene()
        self.sceneManager.onScene = { [preparedData] message in
            XCTAssertEqual(message, preparedData!.message)
            return scene
        }

        let analytics = TestInAppMessageAnalytics()
        self.analyticsFactory.onMake = { [preparedData, preparedInfo] scheduleID, productID, contactID, message, campaigns, reportingContext in
            XCTAssertEqual(scheduleID, preparedInfo.scheduleID)
            XCTAssertEqual(productID, preparedInfo.productID)
            XCTAssertEqual(contactID, preparedInfo.contactID)
            XCTAssertEqual(campaigns, preparedInfo.campaigns)
            XCTAssertEqual(reportingContext, preparedInfo.reportingContext)
            XCTAssertEqual(message, preparedData!.message)
            return analytics
        }

        self.displayAdapter.onDisplay = { incomingScene, incomingAnalytics in
            XCTAssertTrue(scene === (incomingScene as? TestScene))
            XCTAssertTrue(analytics === (incomingAnalytics as? TestInAppMessageAnalytics))
            return .cancel
        }

        let result =  try await self.executor.execute(data: preparedData, preparedScheduleInfo: preparedInfo)

        XCTAssertTrue(self.displayAdapter.displayed)
        XCTAssertEqual(result, .cancel)
        XCTAssertEqual(self.actionRunner.actions, self.preparedData.message.actions)

    }
}


fileprivate final class TestDisplayDelegate: InAppMessageDisplayDelegate, @unchecked Sendable {
    @MainActor
    var onIsReady: ((InAppMessage, String) -> Bool)?

    @MainActor
    var onWillDisplay: ((InAppMessage, String) -> Void)?

    @MainActor
    var onWillDisplayCalled: Bool = false

    @MainActor
    var onFinishedDisplaying: ((InAppMessage, String) -> Void)?

    @MainActor
    var onFinishedDisplayingCalled: Bool = false

    @MainActor
    func isMessageReadyToDisplay(_ message: InAppMessage, scheduleID: String) -> Bool {
        return self.onIsReady!(message, scheduleID)
    }
    
    @MainActor
    func messageWillDisplay(_ message: InAppMessage, scheduleID: String) {
        self.onWillDisplay!(message, scheduleID)
        self.onWillDisplayCalled = true
    }
    
    @MainActor
    func messageFinishedDisplaying(_ message: InAppMessage, scheduleID: String) {
        self.onFinishedDisplaying!(message, scheduleID)
        self.onFinishedDisplayingCalled = true
    }
}

fileprivate final class TestScene: WindowSceneHolder {
    var scene: UIWindowScene {
        fatalError("not able to create a window scene")
    }
}

fileprivate final class TestSceneManager: InAppMessageSceneManagerProtocol, @unchecked Sendable {
    var delegate: AirshipAutomationSwift.InAppMessageSceneDelegate?
    
    @MainActor
    var onScene: ((InAppMessage) throws -> TestScene)?

    func scene(forMessage: InAppMessage) throws -> WindowSceneHolder {
        return try self.onScene!(forMessage)
    }
}


fileprivate final class TestAnalyticsFactory: InAppMessageAnalyticsFactoryProtocol, @unchecked Sendable {
  
    
    @MainActor
    var onMake: ((String, String?, String?, InAppMessage, AirshipJSON?, AirshipJSON?) -> InAppMessageAnalyticsProtocol)?


    @MainActor
    func setOnMake(onMake: @escaping @Sendable (String, String?, String?, InAppMessage, AirshipJSON?, AirshipJSON?) -> InAppMessageAnalyticsProtocol) {
        self.onMake = onMake
    }
    @MainActor
    func makeAnalytics(
        scheduleID: String,
        productID: String?,
        contactID: String?,
        message: InAppMessage,
        campaigns: AirshipJSON?,
        reportingContext: AirshipJSON?,
        experimentResult: ExperimentResult?
    ) -> InAppMessageAnalyticsProtocol {
        return self.onMake!(scheduleID, productID, contactID, message, campaigns, reportingContext)
    }
}
