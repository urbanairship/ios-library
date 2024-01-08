/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomationSwift
import AirshipCore

final class AutomationExecutorTest: XCTestCase {

    private let actionExecutor: TestExecutorDelegate<AirshipJSON> = TestExecutorDelegate()
    private let messageExecutor: TestExecutorDelegate<PreparedInAppMessageData> = TestExecutorDelegate()
    private let remoteDataAccess: TestRemoteDataAccess = TestRemoteDataAccess()
    private var executor: AutomationExecutor!

    override func setUp() async throws {
        self.executor = AutomationExecutor(
            actionExecutor: actionExecutor,
            messageExecutor: messageExecutor,
            remoteDataAccess: remoteDataAccess
        )
    }

    func testMessageIsReady() async throws {
        let messageSchedule = PreparedSchedule(
            info: PreparedScheduleInfo(scheduleID: UUID().uuidString),
            data: .inAppMessage(PreparedInAppMessageData()),
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
            info: PreparedScheduleInfo(scheduleID: UUID().uuidString),
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

    func testFrequencyCheckerCheckFailed() async throws {
        let frequencyChecker = TestFrequencyChecker()

        let schedule = PreparedSchedule(
            info: PreparedScheduleInfo(scheduleID: UUID().uuidString),
            data: .actions(AirshipJSON.string("neat")),
            frequencyChecker: frequencyChecker
        )

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
            info: PreparedScheduleInfo(scheduleID: UUID().uuidString),
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
            info: PreparedScheduleInfo(scheduleID: UUID().uuidString),
            data: .actions(AirshipJSON.string("neat")),
            frequencyChecker: nil
        )

        self.actionExecutor.executeBlock = { data, info in
            XCTAssertEqual(.actions(data), actionSchedule.data)
            XCTAssertEqual(info, actionSchedule.info)
        }

        await self.executor.execute(preparedSchedule: actionSchedule)

        XCTAssertTrue(actionExecutor.executeCalled)
    }

    func testExecuteMessage() async throws {
        let messageSchedule = PreparedSchedule(
            info: PreparedScheduleInfo(scheduleID: UUID().uuidString),
            data: .inAppMessage(PreparedInAppMessageData()),
            frequencyChecker: nil
        )

        self.messageExecutor.executeBlock = { data, info in
            XCTAssertEqual(.inAppMessage(data), messageSchedule.data)
            XCTAssertEqual(info, messageSchedule.info)
        }

        await self.executor.execute(preparedSchedule: messageSchedule)
        XCTAssertTrue(messageExecutor.executeCalled)
    }
    

    func testInterruptedAction() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: "some schedule",
            triggers: [],
            data: .actions(AirshipJSON.string("neat"))
        )

        let preparedScheduleInfo = PreparedScheduleInfo(scheduleID: "some schedule")

        self.actionExecutor.interruptedBlock = { info in
            XCTAssertEqual(info, preparedScheduleInfo)
        }

        await self.executor.interrupted(
            schedule: automationSchedule,
            preparedScheduleInfo: preparedScheduleInfo
        )

        XCTAssertTrue(self.actionExecutor.interruptCalled)
    }

    func testInterruptedMessage() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: "some schedule",
            triggers: [],
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .custom(.null))
            )
        )

        let preparedScheduleInfo = PreparedScheduleInfo(scheduleID: "some schedule")

        self.messageExecutor.interruptedBlock = { info in
            XCTAssertEqual(info, preparedScheduleInfo)
        }

        await self.executor.interrupted(
            schedule: automationSchedule,
            preparedScheduleInfo: preparedScheduleInfo
        )

        XCTAssertTrue(self.messageExecutor.interruptCalled)
    }
}


fileprivate final class TestExecutorDelegate<T: Sendable>: AutomationExecutorDelegate, @unchecked Sendable {
    typealias ExecutionData = T

    var isReadyCalled: Bool = false
    var isReadyBlock: (@Sendable (T, PreparedScheduleInfo) -> ScheduleReadyResult)?

    var executeCalled: Bool = false
    var executeBlock: (@Sendable (T, PreparedScheduleInfo) async -> Void)?

    var interruptCalled: Bool = false
    var interruptedBlock: (@Sendable (PreparedScheduleInfo) async -> Void)?

    @MainActor
    func isReady(
        data: T,
        preparedScheduleInfo: PreparedScheduleInfo
    ) -> ScheduleReadyResult {
        isReadyCalled = true
        return self.isReadyBlock!(data, preparedScheduleInfo)
    }

    @MainActor
    func execute(data: T, preparedScheduleInfo: PreparedScheduleInfo) async {
        executeCalled = true
        return await self.executeBlock!(data, preparedScheduleInfo)
    }


    func interrupted(preparedScheduleInfo: PreparedScheduleInfo) async {
        interruptCalled = true
        return await self.interruptedBlock!(preparedScheduleInfo)
    }
}

final class TestFrequencyChecker: FrequencyCheckerProtocol, @unchecked Sendable {
    var isOverLimit: Bool = false
    var checkAndIncrementBlock: (() -> Bool)?
    var checkAndIncrementCalled: Bool = false

    func checkAndIncrement() -> Bool {
        checkAndIncrementCalled = true
        return checkAndIncrementBlock!()
    }

    @MainActor
    func setIsOverLimit(_ isOverLimit: Bool) {
        self.isOverLimit = isOverLimit
    }

}


fileprivate extension ScheduleReadyResult {
    static var allResults: [ScheduleReadyResult] {
        return [.ready, .notReady, .invalidate, .skip]
    }
}
