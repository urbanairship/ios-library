/* Copyright Airship and Contributors */

import Foundation

import AirshipCore

struct ActionAutomationPreparer: AutomationPreparerDelegate {
    typealias PrepareDataIn = AirshipJSON
    typealias PrepareDataOut = AirshipJSON

    func prepare(data: AirshipJSON, preparedScheduleInfo: PreparedScheduleInfo) async throws -> DelegatePreparerResult<AirshipJSON> {
        return .prepared(data)
    }

    func cancelled(scheduleID: String) async {
        // no-op
    }
}
