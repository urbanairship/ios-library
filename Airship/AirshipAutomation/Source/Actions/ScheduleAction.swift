/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
public import AirshipCore
#endif

/**
 * Action to schedule other actions.
 *
 * This action is registered under the names schedule_actions and ^sa.
 *
 * Expected argument values: Dictionary representing a schedule info JSON.
 *
 * Valid situations: ActionSituation.backgroundPush, .foregroundPush, .webViewInvocation, .manualInvocation, and .automation
 *
 * Result value: Schedule ID or throw if the schedule failed.
 */

public final class ScheduleAction: AirshipAction {
    
    //used for tests
    private let overrideAutomation: (any InAppAutomation)?

    /// Cancel schedules action names.
    public static let defaultNames: [String] = ["schedule_actions", "^sa"]
    
    init(overrideAutomation: (any InAppAutomation)? = nil) {
        self.overrideAutomation = overrideAutomation
    }
    
    var automation: any InAppAutomation {
        return overrideAutomation ?? Airship.inAppAutomation
    }
    
    public func accepts(arguments: ActionArguments) async -> Bool {
        switch arguments.situation {
        case .manualInvocation,
            .backgroundPush,
            .foregroundPush,
            .webViewInvocation,
            .automation:
                return true
        default: return false
        }
    }
    
    public func perform(arguments: ActionArguments) async throws -> AirshipJSON? {
        let schedule: AutomationSchedule = try arguments.value.decode()
        
        try await self.automation.upsertSchedules([schedule])
        
        return .string(schedule.identifier)
    }
}
