/* Copyright Airship and Contributors */

import Foundation
import Combine

@testable import AirshipAutomationSwift
@testable import AirshipCore

final class TestAutomationEngine: AutomationEngineProtocol, @unchecked Sendable {
    var isPaused: Bool = false
    var isExecutionPaused: Bool = false
    var isStarted: Bool = false

    private var onUpsert: (@Sendable ([AutomationSchedule]) async throws -> Void)?
    private var onStop: (@Sendable ([AutomationSchedule]) async throws -> Void)?
    private var onCancel: (@Sendable ([AutomationSchedule]) async throws -> Void)?
    
    private(set) var lastCancelledScheduleId: String?


    func start() {
        isStarted = true
    }


    func setOnStop(_ onStop: @escaping @Sendable ([AutomationSchedule]) async throws -> Void) {
        self.onStop = onStop
    }

    func stopSchedules(_ schedules: [AutomationSchedule]) async throws {
        try await self.onStop!(schedules)
    }

    func setOnUpsert(_ onUpsert: @escaping @Sendable ([AutomationSchedule]) async throws -> Void) {
        self.onUpsert = onUpsert
    }

    func upsertSchedules(_ schedules: [AutomationSchedule]) async throws {
        try await self.onUpsert!(schedules)
    }
    
    func cancelSchedule(identifier: String) async throws {
        self.lastCancelledScheduleId = identifier
        self.schedules.removeAll(where: { $0.identifier == identifier })
    }
    
    func cancelSchedules(group: String) async throws {
        throw AirshipErrors.error("Not implemented")
    }
    
    func schedule(_ schedules: [AutomationSchedule]) async throws {
        self.schedules = schedules
    }
    
    var schedules: [AutomationSchedule] = []

    func getSchedule(identifier: String) async throws -> AutomationSchedule {
        throw AirshipErrors.error("Not implemented")
    }
    
    func getSchedules(group: String) async throws -> [AirshipAutomationSwift.AutomationSchedule] {
        throw AirshipErrors.error("Not implemented")
    }
    
    func scheduleConditionsChanged() {

    }
    

}
