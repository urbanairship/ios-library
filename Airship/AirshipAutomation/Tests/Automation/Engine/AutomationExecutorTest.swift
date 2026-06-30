/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable @_spi(AirshipInternal)
import AirshipAutomation
import AirshipCore
@_spi(AirshipInternal) import AirshipScenes

@MainActor
struct AutomationExecutorTest {

    private let actionExecutor: TestExecutorDelegate<AirshipJSON> = TestExecutorDelegate()
    private let messageExecutor: TestExecutorDelegate<PreparedInAppMessageData> = TestExecutorDelegate()
    private let remoteDataAccess: TestRemoteDataAccess = TestRemoteDataAccess()
    private let messageAnalyitics: TestInAppMessageAnalytics = TestInAppMessageAnalytics()

    private let executor: AutomationExecutor

    private let preparedMessageData: PreparedInAppMessageData

    init() async throws {
        self.preparedMessageData = PreparedInAppMessageData(
            message: InAppMessage(
                name: "some name",
                displayContent: .custom(.string("custom"))
            ),
            displayAdapter: TestDisplayAdapter(),
            displayCoordinator: TestDisplayCoordinator(),
            analytics: messageAnalyitics,
            actionRunner: TestInAppActionRunner()
        )

        self.executor = AutomationExecutor(
            actionExecutor: actionExecutor,
            messageExecutor: messageExecutor,
            remoteDataAccess: remoteDataAccess
        )
    }

    @Test
    func testMessageIsReady() async throws {
        let messageSchedule = PreparedSchedule(
            info: PreparedScheduleInfo(scheduleID: UUID().uuidString, triggerSessionID: UUID().uuidString, priority: 0),
            data: .inAppMessage(self.preparedMessageData),
            frequencyChecker: nil
        )

        for readyResult in ScheduleReadyResult.allResults {
            self.messageExecutor.isReadyCalled = false
            self.messageExecutor.isReadyBlock = { data, info in
                #expect(.inAppMessage(data) == messageSchedule.data)
                #expect(info == messageSchedule.info)
                return readyResult
            }

            let result = self.executor.isReady(
                preparedSchedule: messageSchedule
            )

            #expect(readyResult == result)
            #expect(messageExecutor.isReadyCalled)
        }
    }

    @Test
    func testActionIsReady() async throws {
        let actionSchedule = PreparedSchedule(
            info: PreparedScheduleInfo(scheduleID: UUID().uuidString, triggerSessionID: UUID().uuidString, priority: 0),
            data: .actions(AirshipJSON.string("neat")),
            frequencyChecker: nil
        )

        for readyResult in ScheduleReadyResult.allResults {
            self.actionExecutor.isReadyCalled = false

            self.actionExecutor.isReadyBlock = { data, info in
                #expect(.actions(data) == actionSchedule.data)
                #expect(info == actionSchedule.info)
                return readyResult
            }

            let result = self.executor.isReady(
                preparedSchedule: actionSchedule
            )

            #expect(readyResult == result)
            #expect(actionExecutor.isReadyCalled)
        }
    }

    @Test
    func testFrequencyChekerNotCheckedIfDelegateNotReady() async throws {
        let frequencyChecker = TestFrequencyChecker()

        let schedule = PreparedSchedule(
            info: PreparedScheduleInfo(scheduleID: UUID().uuidString, triggerSessionID: UUID().uuidString, priority: 0),
            data: .actions(AirshipJSON.string("neat")),
            frequencyChecker: frequencyChecker
        )

        self.actionExecutor.isReadyBlock = { _, _ in
            return .notReady
        }

        frequencyChecker.checkAndIncrementBlock = {
            return false
        }

        let result = self.executor.isReady(
            preparedSchedule: schedule
        )

        #expect(result == .notReady)
        #expect(!(frequencyChecker.checkAndIncrementCalled))
    }

    @Test
    func testFrequencyCheckerCheckFailed() async throws {
        let frequencyChecker = TestFrequencyChecker()

        let schedule = PreparedSchedule(
            info: PreparedScheduleInfo(scheduleID: UUID().uuidString, triggerSessionID: UUID().uuidString, priority: 0),
            data: .actions(AirshipJSON.string("neat")),
            frequencyChecker: frequencyChecker
        )

        self.actionExecutor.isReadyBlock = { _, _ in
            return .ready
        }
        
        frequencyChecker.checkAndIncrementBlock = {
            return false
        }

        let result = self.executor.isReady(
            preparedSchedule: schedule
        )

        #expect(result == .skip)
        #expect(frequencyChecker.checkAndIncrementCalled)
    }

    @Test
    func testFrequencyCheckerCheckSuccess() async throws {
        let frequencyChecker = TestFrequencyChecker()

        let schedule = PreparedSchedule(
            info: PreparedScheduleInfo(scheduleID: UUID().uuidString, triggerSessionID: UUID().uuidString, priority: 0),
            data: .actions(AirshipJSON.string("neat")),
            frequencyChecker: frequencyChecker
        )

        frequencyChecker.checkAndIncrementBlock = {
            return true
        }

        self.actionExecutor.isReadyBlock = { _, _ in
            return .ready
        }

        let result = self.executor.isReady(
            preparedSchedule: schedule
        )

        #expect(result == .ready)
        #expect(frequencyChecker.checkAndIncrementCalled)
        #expect(actionExecutor.isReadyCalled)
    }

    @Test
    func testIsValid() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: "some schedule",
            triggers: [],
            data: .actions(AirshipJSON.null)
        )

        self.remoteDataAccess.isCurrentBlock = { schedule in
            #expect(schedule == automationSchedule)
            return true
        }

        let result = await self.executor.isValid(schedule: automationSchedule)
        #expect(result)
    }

    @Test
    func testIsValidFals() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: "some schedule",
            triggers: [],
            data: .actions(AirshipJSON.null)
        )

        self.remoteDataAccess.isCurrentBlock = { schedule in
            #expect(schedule == automationSchedule)
            return false
        }

        let result = await self.executor.isValid(schedule: automationSchedule)
        #expect(!(result))
    }

    @Test
    func testExecuteActions() async throws {
        let actionSchedule = PreparedSchedule(
            info: PreparedScheduleInfo(scheduleID: UUID().uuidString, triggerSessionID: UUID().uuidString, priority: 0),
            data: .actions(AirshipJSON.string("neat")),
            frequencyChecker: nil
        )

        self.actionExecutor.executeBlock = { data, info in
            #expect(.actions(data) == actionSchedule.data)
            #expect(info == actionSchedule.info)
            return .finished
        }

        let result = await self.executor.execute(preparedSchedule: actionSchedule)

        #expect(actionExecutor.executeCalled)
        #expect(result == .finished)
    }

    @Test
    func testExecuteMessage() async throws {
        let messageSchedule = PreparedSchedule(
            info: PreparedScheduleInfo(scheduleID: UUID().uuidString, triggerSessionID: UUID().uuidString, priority: 0),
            data: .inAppMessage(self.preparedMessageData),
            frequencyChecker: nil
        )

        self.messageExecutor.executeBlock = { data, info in
            #expect(.inAppMessage(data) == messageSchedule.data)
            #expect(info == messageSchedule.info)
            return .finished
        }

        let result = await self.executor.execute(preparedSchedule: messageSchedule)
        #expect(messageExecutor.executeCalled)
        #expect(result == .finished)
    }

    @Test
    func testExecuteDelegateThrows() async throws {
        let messageSchedule = PreparedSchedule(
            info: PreparedScheduleInfo(scheduleID: UUID().uuidString, triggerSessionID: UUID().uuidString, priority: 0),
            data: .inAppMessage(self.preparedMessageData),
            frequencyChecker: nil
        )

        self.messageExecutor.executeBlock = { data, info in
            throw AirshipErrors.error("Failed")
        }

        let result = await self.executor.execute(preparedSchedule: messageSchedule)
        #expect(messageExecutor.executeCalled)
        #expect(result == .retry)
    }


    @Test
    func testInterruptedAction() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: "some schedule",
            triggers: [],
            data: .actions(AirshipJSON.string("neat"))
        )

        let preparedScheduleInfo = PreparedScheduleInfo(scheduleID: "some schedule", triggerSessionID: UUID().uuidString, priority: 0)

        self.actionExecutor.interruptedBlock = { info in
            #expect(info == preparedScheduleInfo)
            return .retry
        }

        let result = await self.executor.interrupted(
            schedule: automationSchedule,
            preparedScheduleInfo: preparedScheduleInfo
        )

        #expect(self.actionExecutor.interruptCalled)
        #expect(result == .retry)
    }

    @Test
    func testInterruptedMessage() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: "some schedule",
            triggers: [],
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .custom(.null))
            )
        )

        let preparedScheduleInfo = PreparedScheduleInfo(scheduleID: "some schedule",  triggerSessionID: UUID().uuidString, priority: 0)

        self.messageExecutor.interruptedBlock = { info in
            #expect(info == preparedScheduleInfo)
            return .finish
        }

        let result = await self.executor.interrupted(
            schedule: automationSchedule,
            preparedScheduleInfo: preparedScheduleInfo
        )

        #expect(self.messageExecutor.interruptCalled)
        #expect(result == .finish)
    }
}


fileprivate final class TestExecutorDelegate<T: Sendable>: AutomationExecutorDelegate, @unchecked Sendable {

    
    typealias ExecutionData = T

    var isReadyCalled: Bool = false
    var isReadyBlock: (@Sendable (T, PreparedScheduleInfo) -> ScheduleReadyResult)?

    var executeCalled: Bool = false
    var executeBlock: (@Sendable (T, PreparedScheduleInfo) async throws -> ScheduleExecuteResult)?

    var interruptCalled: Bool = false
    var interruptedBlock: (@Sendable (PreparedScheduleInfo) async -> InterruptedBehavior)?

    @MainActor
    func isReady(
        data: T,
        preparedScheduleInfo: PreparedScheduleInfo
    ) -> ScheduleReadyResult {
        isReadyCalled = true
        return self.isReadyBlock!(data, preparedScheduleInfo)
    }

    @MainActor
    func execute(data: T, preparedScheduleInfo: PreparedScheduleInfo) async throws -> ScheduleExecuteResult {
        executeCalled = true
        return try await self.executeBlock!(data, preparedScheduleInfo)
    }


    func interrupted(schedule: AutomationSchedule, preparedScheduleInfo: PreparedScheduleInfo) async -> InterruptedBehavior {
        interruptCalled = true
        return await self.interruptedBlock!(preparedScheduleInfo)
    }
}

extension ScheduleReadyResult {
    static var allResults: [ScheduleReadyResult] {
        return [.ready, .notReady, .invalidate, .skip]
    }
}


final class TestInAppActionRunner: InternalInAppActionRunner, @unchecked Sendable {

    var singleActions: [(String, ActionArguments, ThomasLayoutContext?)] = []
    var actionPayloads: [(AirshipJSON, ThomasLayoutContext?)] = []

    func runAsync(actions: AirshipJSON, layoutContext: ThomasLayoutContext) {
        actionPayloads.append((actions, layoutContext))
    }

    func run(actionName: String, arguments: ActionArguments, layoutContext: ThomasLayoutContext) async -> ActionResult {
        singleActions.append((actionName, arguments, layoutContext))
        return .error(AirshipErrors.error("not implemented"))
    }

    func run(actionName: String, arguments: ActionArguments) async -> ActionResult {
        singleActions.append((actionName, arguments, nil))
        return .error(AirshipErrors.error("not implemented"))
    }

    func runAsync(actions: AirshipJSON) {
        actionPayloads.append((actions, nil))
    }

    func run(actions: AirshipJSON) async {
        actionPayloads.append((actions, nil))
    }

}
