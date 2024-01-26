/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif


final class AutomationStore: Sendable {
    var schedules: [AutomationScheduleData] {
        get async throws {
            return []
        }
    }

    /// Updates are inserts using the updateBlock. Returns an array of any schedules that changed.
    func batchUpsert(
        identifiers: [String],
        updateBlock: @Sendable (String, AutomationScheduleData?) throws -> AutomationScheduleData
    ) async throws -> [AutomationScheduleData] {
        return []
    }

    func delete(identifiers: [String]) async throws {

    }

    func delete(group: String) async throws {

    }

    func getSchedule(identifier: String) async throws -> AutomationScheduleData? {
        return nil
    }

    func getSchedules(group: String) async throws -> [AutomationScheduleData] {
        return []
    }

    func getSchedules(identifiers: [String]) async throws -> [AutomationScheduleData] {
        return []
    }


    @discardableResult
    func update(
        identifier: String,
        block: @escaping @Sendable (inout AutomationScheduleData) throws -> Void) async throws -> AutomationScheduleData? {
        return nil
    }
}
