/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

struct ActionAutomationPreparer: AutomationPreparerDelegate {
    typealias PrepareDataIn = AirshipJSON
    typealias PrepareDataOut = AirshipJSON

    func prepare(data: AirshipJSON, preparedScheduleInfo: PreparedScheduleInfo) async throws -> AirshipJSON {
        return data
    }

    func cancelled(scheduleID: String) async {
        // no-op
    }
}
