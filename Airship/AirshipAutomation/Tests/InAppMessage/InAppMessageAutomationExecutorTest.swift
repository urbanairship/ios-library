/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipAutomation
import AirshipCore

final class InAppMessageAutomationExecutorTest: XCTestCase {

    private let sceneManager: TestSceneManager = TestSceneManager()
    private let assetManager: TestAssetManager = TestAssetManager()
    private let analyticsFactory: TestAnalyticsFactory = TestAnalyticsFactory()
    private var conditionsChangedNotifier: ScheduleConditionsChangedNotifier!
    private let analytics: TestInAppMessageAnalytics = TestInAppMessageAnalytics()
    private let actionRunner: TestInAppActionRunner = TestInAppActionRunner()
    private var displayAdapter: TestDisplayAdapter!


    private let preparedInfo: PreparedScheduleInfo = PreparedScheduleInfo(
        scheduleID: UUID().uuidString,
        productID: UUID().uuidString,
        campaigns: .string(UUID().uuidString),
        contactID: UUID().uuidString,
        reportingContext: .string(UUID().uuidString),
        triggerSessionID: UUID().uuidString,
        priority: 0
    )

    private var displayCoordinator: TestDisplayCoordinator!
    private var preparedData: PreparedInAppMessageData!
    private var executor: InAppMessageAutomationExecutor!

    @MainActor
    override func setUp() async throws {
        self.displayAdapter = TestDisplayAdapter()
        self.conditionsChangedNotifier = ScheduleConditionsChangedNotifier()
        self.displayCoordinator = TestDisplayCoordinator()
        self.preparedData = PreparedInAppMessageData(
            message: InAppMessage(
                name: "",
                displayContent: .custom(.string("")),
                actions: .string("actions payload")
            ),
            displayAdapter: self.displayAdapter,
            displayCoordinator: self.displayCoordinator,
            analytics: analytics,
            actionRunner: actionRunner
        )

        self.executor = InAppMessageAutomationExecutor(
            sceneManager: sceneManager,
            assetManager: assetManager,
            analyticsFactory: analyticsFactory,
            scheduleConditionsChangedNotifier: conditionsChangedNotifier
        )

        self.analyticsFactory.setOnMake { _, _ in
            return self.analytics
        }
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

        _ = await self.executor.interrupted(schedule: schedule, preparedScheduleInfo: preparedInfo)
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

        self.displayAdapter.onDisplay = { [preparedData] incomingScene, incomingAnalytics in
            XCTAssertTrue(scene === (incomingScene as? TestScene))
            XCTAssertTrue(preparedData!.analytics === incomingAnalytics)
            return .finished
        }

        let result =  try await self.executor.execute(data: preparedData, preparedScheduleInfo: preparedInfo)
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
            channelID: "some channel",
            contactID: "some contact",
            isMatch: true,
            reportingMetadata: []
        )
        var preparedInfo = preparedInfo
        preparedInfo.experimentResult = experimentResult

        let result = try await self.executor.execute(data: preparedData, preparedScheduleInfo: preparedInfo)

        XCTAssertEqual(analytics.events.first!.0.name, InAppResolutionEvent.control(experimentResult: experimentResult).name)
        XCTAssertFalse(self.displayAdapter.displayed)
        XCTAssertEqual(result, .finished)
        XCTAssertTrue(self.actionRunner.actionPayloads.isEmpty)
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
        self.analyticsFactory.onMake = { [preparedData, preparedInfo] incomingInfo, incomingMessage in
            XCTAssertEqual(incomingInfo, preparedInfo)
            XCTAssertEqual(incomingMessage, preparedData!.message)
            return analytics
        }


        self.displayAdapter.onDisplay = { incomingScene, incomingAnalytics in
            throw AirshipErrors.error("Failed")
        }

        let result =  try await self.executor.execute(data: preparedData, preparedScheduleInfo: preparedInfo)

        XCTAssertTrue(self.displayAdapter.displayed)
        XCTAssertEqual(result, .retry)
        XCTAssertTrue(self.actionRunner.actionPayloads.isEmpty)
    }

    @MainActor
    func testAdditionalAudienceCheckMiss() async throws  {
        self.displayAdapter.onDisplay = { incomingScene, incomingAnalytics in
            throw AirshipErrors.error("Failed")
        }
        var preparedInfo = preparedInfo
        preparedInfo.additionalAudienceCheckResult = false

        let result =  try await self.executor.execute(
            data: preparedData,
            preparedScheduleInfo: preparedInfo
        )

        XCTAssertEqual(analytics.events.first!.0.name, InAppResolutionEvent.audienceExcluded().name)
        XCTAssertFalse(self.displayAdapter.displayed)
        XCTAssertEqual(result, .finished)
        XCTAssertTrue(self.actionRunner.actionPayloads.isEmpty)
    }

    @MainActor
    func testExecuteNoScene() async throws  {
        self.sceneManager.onScene = { _ in
            throw AirshipErrors.error("Fail")
        }

        self.displayAdapter.onDisplay = { _, _ in
            XCTFail()
            return .cancel
        }

        do {
            _ = try await self.executor.execute(data: preparedData, preparedScheduleInfo: preparedInfo)
            XCTFail("should throw")
        } catch {}

        XCTAssertTrue(self.actionRunner.actionPayloads.isEmpty)
    }

    @MainActor
    func testExecuteCancel() async throws  {
        let scene = TestScene()
        self.sceneManager.onScene = { [preparedData] message in
            XCTAssertEqual(message, preparedData!.message)
            return scene
        }

        self.displayAdapter.onDisplay = { [preparedData] incomingScene, incomingAnalytics in
            XCTAssertTrue(scene === (incomingScene as? TestScene))
            XCTAssertTrue(preparedData!.analytics === incomingAnalytics)
            return .cancel
        }

        let result =  try await self.executor.execute(data: preparedData, preparedScheduleInfo: preparedInfo)

        XCTAssertTrue(self.displayAdapter.displayed)
        XCTAssertEqual(result, .cancel)
        XCTAssertEqual(self.actionRunner.actionPayloads.first!.0, self.preparedData.message.actions)
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
    var delegate: InAppMessageSceneDelegate?
    
    @MainActor
    var onScene: ((InAppMessage) throws -> TestScene)?

    func scene(forMessage: InAppMessage) throws -> WindowSceneHolder {
        return try self.onScene!(forMessage)
    }
}


final class TestAnalyticsFactory: InAppMessageAnalyticsFactoryProtocol, @unchecked Sendable {
    func makeAnalytics(preparedScheduleInfo: PreparedScheduleInfo, message: InAppMessage) async -> any InAppMessageAnalyticsProtocol {
        return await self.onMake!(preparedScheduleInfo, message)
    }

    @MainActor
    var onMake: ((PreparedScheduleInfo, InAppMessage) async -> InAppMessageAnalyticsProtocol)?


    @MainActor
    func setOnMake(onMake: @escaping @Sendable (PreparedScheduleInfo, InAppMessage) -> InAppMessageAnalyticsProtocol) {
        self.onMake = onMake
    }
}
