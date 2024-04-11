/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomation
import AirshipCore

final class AutomationExecutorTest: XCTestCase {

    private let actionExecutor: TestExecutorDelegate<AirshipJSON> = TestExecutorDelegate()
    private let messageExecutor: TestExecutorDelegate<PreparedInAppMessageData> = TestExecutorDelegate()
    private let remoteDataAccess: TestRemoteDataAccess = TestRemoteDataAccess()
    private let messageAnalyitics: TestInAppMessageAnalytics = TestInAppMessageAnalytics()

    private var executor: AutomationExecutor!

    private var preparedMessageData: PreparedInAppMessageData!

    @MainActor
    override func setUp() async throws {
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

    func testMessageIsReady() async throws {
        let messageSchedule = PreparedSchedule(
            info: PreparedScheduleInfo(scheduleID: UUID().uuidString, triggerSessionID: UUID().uuidString),
            data: .inAppMessage(self.preparedMessageData),
            frequencyChecker: nil
        )

        for readyResult in ScheduleReadyResult.allResults {
            self.messageExecutor.isReadyCalled = false
            self.messageExecutor.isReadyBlock = { data, info in
                XCTAssertEqual(.inAppMessage(data), messageSchedule.data)
                XCTAssertEqual(info, messageSchedule.info)
                return readyResult
            }

            let result = await self.executor.isReady(
                preparedSchedule: messageSchedule
            )

            XCTAssertEqual(readyResult, result)
            XCTAssertTrue(messageExecutor.isReadyCalled)
        }
    }

    func testActionIsReady() async throws {
        let actionSchedule = PreparedSchedule(
            info: PreparedScheduleInfo(scheduleID: UUID().uuidString, triggerSessionID: UUID().uuidString),
            data: .actions(AirshipJSON.string("neat")),
            frequencyChecker: nil
        )

        for readyResult in ScheduleReadyResult.allResults {
            self.actionExecutor.isReadyCalled = false

            self.actionExecutor.isReadyBlock = { data, info in
                XCTAssertEqual(.actions(data), actionSchedule.data)
                XCTAssertEqual(info, actionSchedule.info)
                return readyResult
            }

            let result = await self.executor.isReady(
                preparedSchedule: actionSchedule
            )

            XCTAssertEqual(readyResult, result)
            XCTAssertTrue(actionExecutor.isReadyCalled)
        }
    }

    func testFrequencyChekerNotCheckedIfDelegateNotReady() async throws {
        let frequencyChecker = TestFrequencyChecker()

        let schedule = PreparedSchedule(
            info: PreparedScheduleInfo(scheduleID: UUID().uuidString, triggerSessionID: UUID().uuidString),
            data: .actions(AirshipJSON.string("neat")),
            frequencyChecker: frequencyChecker
        )

        self.actionExecutor.isReadyBlock = { _, _ in
            return .notReady
        }

        frequencyChecker.checkAndIncrementBlock = {
            return false
        }

        let result = await self.executor.isReady(
            preparedSchedule: schedule
        )

        XCTAssertEqual(result, .notReady)
        XCTAssertFalse(frequencyChecker.checkAndIncrementCalled)
    }

    func testFrequencyCheckerCheckFailed() async throws {
        let frequencyChecker = TestFrequencyChecker()

        let schedule = PreparedSchedule(
            info: PreparedScheduleInfo(scheduleID: UUID().uuidString, triggerSessionID: UUID().uuidString),
            data: .actions(AirshipJSON.string("neat")),
            frequencyChecker: frequencyChecker
        )

        self.actionExecutor.isReadyBlock = { _, _ in
            return .ready
        }
        
        frequencyChecker.checkAndIncrementBlock = {
            return false
        }

        let result = await self.executor.isReady(
            preparedSchedule: schedule
        )

        XCTAssertEqual(result, .skip)
        XCTAssertTrue(frequencyChecker.checkAndIncrementCalled)
    }

    func testFrequencyCheckerCheckSuccess() async throws {
        let frequencyChecker = TestFrequencyChecker()

        let schedule = PreparedSchedule(
            info: PreparedScheduleInfo(scheduleID: UUID().uuidString, triggerSessionID: UUID().uuidString),
            data: .actions(AirshipJSON.string("neat")),
            frequencyChecker: frequencyChecker
        )

        frequencyChecker.checkAndIncrementBlock = {
            return true
        }

        self.actionExecutor.isReadyBlock = { _, _ in
            return .ready
        }

        let result = await self.executor.isReady(
            preparedSchedule: schedule
        )

        XCTAssertEqual(result, .ready)
        XCTAssertTrue(frequencyChecker.checkAndIncrementCalled)
        XCTAssertTrue(actionExecutor.isReadyCalled)
    }

    func testIsReadyPrecheckCurrent() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: "some schedule",
            triggers: [],
            data: .actions(AirshipJSON.null)
        )

        self.remoteDataAccess.isCurrentBlock = { schedule in
            XCTAssertEqual(schedule, automationSchedule)
            return true
        }

        let result = await self.executor.isReadyPrecheck(schedule: automationSchedule)
        XCTAssertEqual(result, .ready)
    }

    func testIsReadyPrecheckNotCurrent() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: "some schedule",
            triggers: [],
            data: .actions(AirshipJSON.null)
        )

        self.remoteDataAccess.isCurrentBlock = { schedule in
            XCTAssertEqual(schedule, automationSchedule)
            return false
        }

        let result = await self.executor.isReadyPrecheck(schedule: automationSchedule)
        XCTAssertEqual(result, .invalidate)
    }

    func testExecuteActions() async throws {
        let actionSchedule = PreparedSchedule(
            info: PreparedScheduleInfo(scheduleID: UUID().uuidString, triggerSessionID: UUID().uuidString),
            data: .actions(AirshipJSON.string("neat")),
            frequencyChecker: nil
        )

        self.actionExecutor.executeBlock = { data, info in
            XCTAssertEqual(.actions(data), actionSchedule.data)
            XCTAssertEqual(info, actionSchedule.info)
            return .finished
        }

        let result = await self.executor.execute(preparedSchedule: actionSchedule)

        XCTAssertTrue(actionExecutor.executeCalled)
        XCTAssertEqual(result, .finished)
    }

    func testExecuteMessage() async throws {
        let messageSchedule = PreparedSchedule(
            info: PreparedScheduleInfo(scheduleID: UUID().uuidString, triggerSessionID: UUID().uuidString),
            data: .inAppMessage(self.preparedMessageData),
            frequencyChecker: nil
        )

        self.messageExecutor.executeBlock = { data, info in
            XCTAssertEqual(.inAppMessage(data), messageSchedule.data)
            XCTAssertEqual(info, messageSchedule.info)
            return .finished
        }

        let result = await self.executor.execute(preparedSchedule: messageSchedule)
        XCTAssertTrue(messageExecutor.executeCalled)
        XCTAssertEqual(result, .finished)
    }

    func testExecuteDelegateThrows() async throws {
        let messageSchedule = PreparedSchedule(
            info: PreparedScheduleInfo(scheduleID: UUID().uuidString, triggerSessionID: UUID().uuidString),
            data: .inAppMessage(self.preparedMessageData),
            frequencyChecker: nil
        )

        self.messageExecutor.executeBlock = { data, info in
            throw AirshipErrors.error("Failed")
        }

        let result = await self.executor.execute(preparedSchedule: messageSchedule)
        XCTAssertTrue(messageExecutor.executeCalled)
        XCTAssertEqual(result, .retry)
    }


    func testInterruptedAction() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: "some schedule",
            triggers: [],
            data: .actions(AirshipJSON.string("neat"))
        )

        let preparedScheduleInfo = PreparedScheduleInfo(scheduleID: "some schedule", triggerSessionID: UUID().uuidString)

        self.actionExecutor.interruptedBlock = { info in
            XCTAssertEqual(info, preparedScheduleInfo)
            return .retry
        }

        let result = await self.executor.interrupted(
            schedule: automationSchedule,
            preparedScheduleInfo: preparedScheduleInfo
        )

        XCTAssertTrue(self.actionExecutor.interruptCalled)
        XCTAssertEqual(result, .retry)
    }

    func testInterruptedMessage() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: "some schedule",
            triggers: [],
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .custom(.null))
            )
        )

        let preparedScheduleInfo = PreparedScheduleInfo(scheduleID: "some schedule",  triggerSessionID: UUID().uuidString)

        self.messageExecutor.interruptedBlock = { info in
            XCTAssertEqual(info, preparedScheduleInfo)
            return .finish
        }

        let result = await self.executor.interrupted(
            schedule: automationSchedule,
            preparedScheduleInfo: preparedScheduleInfo
        )

        XCTAssertTrue(self.messageExecutor.interruptCalled)
        XCTAssertEqual(result, .finish)
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

extension PreparedScheduleData: Equatable {
    public static func == (lhs: PreparedScheduleData, rhs: PreparedScheduleData) -> Bool {
        switch lhs {
        case  .actions(let lhsJson):
            switch rhs {
            case .actions(let rhsJson): return lhsJson == rhsJson
            default: return false
            }
        case .inAppMessage(let lhsMessageData):
            switch rhs {
            case .inAppMessage(let rhsMessageData):
                return rhsMessageData.message == lhsMessageData.message
            default: return false
            }
        }
    }
}

final class TestInAppActionRunner: InternalInAppActionRunner, @unchecked Sendable {

    var singleActions: [(String, ActionArguments, ThomasLayoutContext?)] = []
    var actionPayloads: [(AirshipJSON, ThomasLayoutContext?)] = []

    func runAsync(actions: AirshipJSON, layoutContext: ThomasLayoutContext?) {
        actionPayloads.append((actions, layoutContext))
    }

    func run(actionName: String, arguments: ActionArguments, layoutContext: ThomasLayoutContext?) async -> ActionResult {
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
