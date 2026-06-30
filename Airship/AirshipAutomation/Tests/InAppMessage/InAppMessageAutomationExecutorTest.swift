/* Copyright Airship and Contributors */

import Testing
import Foundation
@testable @_spi(AirshipInternal) import AirshipAutomation
import AirshipCore
@_spi(AirshipInternal) import AirshipScenes
import UIKit

@MainActor
struct InAppMessageAutomationExecutorTest {

    private let sceneManager: TestSceneManager = TestSceneManager()
    private let assetManager: TestAssetManager = TestAssetManager()
    private let analyticsFactory: TestAnalyticsFactory = TestAnalyticsFactory()
    private let conditionsChangedNotifier: ScheduleConditionsChangedNotifier
    private let analytics: TestInAppMessageAnalytics = TestInAppMessageAnalytics()
    private let actionRunner: TestInAppActionRunner = TestInAppActionRunner()
    private let displayAdapter: TestDisplayAdapter


    private let preparedInfo: PreparedScheduleInfo = PreparedScheduleInfo(
        scheduleID: UUID().uuidString,
        productID: UUID().uuidString,
        campaigns: .string(UUID().uuidString),
        contactID: UUID().uuidString,
        reportingContext: .string(UUID().uuidString),
        triggerSessionID: UUID().uuidString,
        priority: 0
    )

    private let displayCoordinator: TestDisplayCoordinator
    private let preparedData: PreparedInAppMessageData!
    private let executor: InAppMessageAutomationExecutor

    init() async throws {
        self.displayAdapter = TestDisplayAdapter()
        self.conditionsChangedNotifier = ScheduleConditionsChangedNotifier()
        self.displayCoordinator = TestDisplayCoordinator()
        self.preparedData = PreparedInAppMessageData(
            message: InAppMessage(
                name: "",
                displayContent: .custom(.string("")),
                actions: "actions payload"
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

        let analytics = self.analytics
        self.analyticsFactory.setOnMake { _, _ in
            analytics
        }
    }

    @Test
    func testIsReady() {
        self.displayAdapter.isReady = true
        self.displayCoordinator.isReady = true
        #expect(
            self.executor.isReady(data: preparedData, preparedScheduleInfo: preparedInfo) == .ready
        )
    }

    @Test
    func testNotReadyAdapter() {
        self.displayAdapter.isReady = false
        self.displayCoordinator.isReady = true
        #expect(
            self.executor.isReady(data: preparedData, preparedScheduleInfo: preparedInfo) == .notReady
        )
    }

    @Test
    func testNotReadyCoordinator() {
        self.displayAdapter.isReady = true
        self.displayCoordinator.isReady = false
        #expect(
            self.executor.isReady(data: preparedData, preparedScheduleInfo: preparedInfo) == .notReady
        )
    }

    @Test
    func testIsReadyDelegate() {
        self.displayAdapter.isReady = true
        self.displayCoordinator.isReady = true

        let delegate = TestDisplayDelegate()
        delegate.onIsReady = { [preparedData, preparedInfo] message, scheduleID in
            #expect(message == preparedData!.message)
            #expect(scheduleID == preparedInfo.scheduleID)
            return true
        }
        self.executor.displayDelegate = delegate

        #expect(
            self.executor.isReady(data: preparedData, preparedScheduleInfo: preparedInfo) == .ready
        )

        delegate.onIsReady = { [preparedData, preparedInfo] message, scheduleID in
            #expect(message == preparedData!.message)
            #expect(scheduleID == preparedInfo.scheduleID)
            return false
        }

        #expect(
            self.executor.isReady(data: preparedData, preparedScheduleInfo: preparedInfo) == .notReady
        )
    }

    @Test
    func testInterrupted() async throws {
        let schedule = AutomationSchedule(
            identifier: preparedInfo.scheduleID,
            triggers: [],
            data: .inAppMessage(preparedData.message)
        )

        _ = await self.executor.interrupted(schedule: schedule, preparedScheduleInfo: preparedInfo)
        let cleared = await self.assetManager.cleared
        #expect([self.preparedInfo.scheduleID] == cleared)
        #expect(analytics.events.first!.0.name == ThomasLayoutResolutionEvent.interrupted().name)
    }

    @Test
    func testExecute() async throws  {
        self.displayAdapter.onDisplay = { [preparedData] displayTarget, incomingAnalytics in
            #expect(preparedData!.analytics === incomingAnalytics)
            return .finished
        }

        let result =  try await self.executor.execute(data: preparedData, preparedScheduleInfo: preparedInfo)
        #expect(self.displayAdapter.displayed)
        #expect(result == .finished)
    }

    @Test
    func testExecuteInControlGroup() async throws  {
        let scene = TestScene()
        self.sceneManager.onScene = { [preparedData] message in
            #expect(message == preparedData!.message)
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

        #expect(analytics.events.first!.0.name == ThomasLayoutResolutionEvent.control(experimentResult: experimentResult).name)
        #expect(!(self.displayAdapter.displayed))
        #expect(result == .finished)
        #expect(self.actionRunner.actionPayloads.isEmpty)
    }

    @Test
    func testExecuteDisplayAdapter() async throws  {
        let delegate = TestDisplayDelegate()
        self.executor.displayDelegate = delegate

        delegate.onWillDisplay = { [preparedData, preparedInfo] message, scheduleID in
            #expect(message == preparedData!.message)
            #expect(scheduleID == preparedInfo.scheduleID)
        }

        delegate.onFinishedDisplaying = { [preparedData, preparedInfo] message, scheduleID in
            #expect(message == preparedData!.message)
            #expect(scheduleID == preparedInfo.scheduleID)
        }

        self.sceneManager.onScene = { _ in
            return TestScene()
        }

        self.displayAdapter.onDisplay = { _, _ in
            #expect(delegate.onWillDisplayCalled)
            #expect(!(delegate.onFinishedDisplayingCalled))
            return .finished
        }

        let result = try await self.executor.execute(data: preparedData, preparedScheduleInfo: preparedInfo)
        #expect(delegate.onWillDisplayCalled)
        #expect(delegate.onWillDisplayCalled)
        #expect(self.displayAdapter.displayed)
        #expect(result == .finished)
    }

    @Test
    func testExecuteDisplayException() async throws  {
        let scene = TestScene()
        self.sceneManager.onScene = { [preparedData] message in
            #expect(message == preparedData!.message)
            return scene
        }

        let analytics = TestInAppMessageAnalytics()
        self.analyticsFactory.onMake = { [preparedData, preparedInfo] incomingInfo, incomingMessage in
            #expect(incomingInfo == preparedInfo)
            #expect(incomingMessage == preparedData!.message)
            return analytics
        }


        self.displayAdapter.onDisplay = { incomingScene, incomingAnalytics in
            throw AirshipErrors.error("Failed")
        }

        let result =  try await self.executor.execute(data: preparedData, preparedScheduleInfo: preparedInfo)

        #expect(self.displayAdapter.displayed)
        #expect(result == .cancel)
        #expect(self.actionRunner.actionPayloads.isEmpty)
    }

    @Test
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

        #expect(analytics.events.first!.0.name == ThomasLayoutResolutionEvent.audienceExcluded().name)
        #expect(!(self.displayAdapter.displayed))
        #expect(result == .finished)
        #expect(self.actionRunner.actionPayloads.isEmpty)
    }

    @Test
    func testDisplayTargetNoScene() async throws  {
        self.sceneManager.onScene = { _ in
            throw AirshipErrors.error("Fail")
        }

        self.displayAdapter.onDisplay = { displayTarget, _ in
            _ = try displayTarget.sceneProvider()
            return .cancel
        }

        let result = try await self.executor.execute(data: preparedData, preparedScheduleInfo: preparedInfo)
        #expect(result == .cancel)
    }

    @Test
    func testExecuteCancel() async throws  {

        self.displayAdapter.onDisplay = { [preparedData] displayTarget, incomingAnalytics in
            #expect(preparedData!.analytics === incomingAnalytics)
            return .cancel
        }

        let result =  try await self.executor.execute(data: preparedData, preparedScheduleInfo: preparedInfo)

        #expect(self.displayAdapter.displayed)
        #expect(result == .cancel)
        #expect(self.actionRunner.actionPayloads.first!.0 == self.preparedData.message.actions)
    }
}


fileprivate final class TestDisplayDelegate: InAppMessageDisplayDelegate, @unchecked Sendable {
    @MainActor
    init() {}

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
    @MainActor
    init() {}

    var delegate: InAppMessageSceneDelegate?
    
    @MainActor
    var onScene: ((InAppMessage) throws -> TestScene)?

    func scene(forMessage: InAppMessage) throws -> WindowSceneHolder {
        return try self.onScene!(forMessage)
    }
}


final class TestAnalyticsFactory: InAppMessageAnalyticsFactoryProtocol, @unchecked Sendable {
    @MainActor
    init() {}

    func makeAnalytics(preparedScheduleInfo: PreparedScheduleInfo, message: InAppMessage) async -> any InAppMessageAnalyticsProtocol {
        return await self.onMake!(preparedScheduleInfo, message)
    }

    @MainActor
    var onMake: (@Sendable (PreparedScheduleInfo, InAppMessage) async -> any InAppMessageAnalyticsProtocol)?


    @MainActor
    func setOnMake(onMake: @escaping @Sendable (PreparedScheduleInfo, InAppMessage) -> InAppMessageAnalyticsProtocol) {
        self.onMake = onMake
    }
}
