/* Copyright Airship and Contributors */

import Foundation
import Combine

@testable import AirshipAutomation
@testable import AirshipCore

actor TestAutomationEngine: AutomationEngineProtocol {
    @MainActor
    var isPaused: Bool = false
    @MainActor
    var isExecutionPaused: Bool = false
    var isStarted: Bool = false

    private var onUpsert: (@Sendable ([AutomationSchedule]) async throws -> Void)?
    private var onStop: (@Sendable ([AutomationSchedule]) async throws -> Void)?
    private var onCancel: (@Sendable ([AutomationSchedule]) async throws -> Void)?
    
    private(set) var cancelledSchedules: [String] = []

    @MainActor
    func setEnginePaused(_ paused: Bool) {
        self.isPaused = true
    }

    @MainActor
    func setExecutionPaused(_ paused: Bool) {
        self.isExecutionPaused = true
    }


    func start() {
        isStarted = true
    }


    func setOnStop(_ onStop: @escaping @Sendable ([AutomationSchedule]) async throws -> Void) {
        self.onStop = onStop
    }

    func stopSchedules(identifiers: [String]) async throws {
        try await self.onStop!(schedules)
    }

    func setOnUpsert(_ onUpsert: @escaping @Sendable ([AutomationSchedule]) async throws -> Void) {
        self.onUpsert = onUpsert
    }

    func upsertSchedules(_ schedules: [AutomationSchedule]) async throws {
        self.schedules.removeAll { schedule in
            schedules.contains { incoming in
                incoming.identifier == schedule.identifier
            }
        }

        self.schedules.append(contentsOf: schedules)
        try await self.onUpsert?(schedules)
    }
    
    func cancelSchedule(identifier: String) async throws {

    }
    
    func cancelSchedules(identifiers: [String]) async throws {
        self.cancelledSchedules.append(contentsOf: identifiers)

        let set = Set(identifiers)
        self.schedules.removeAll(where: { set.contains($0.identifier) })
    }

    func cancelSchedules(group: String) async throws {
        throw AirshipErrors.error("Not implemented")
    }


    private(set) var schedules: [AutomationSchedule] = []

    func setSchedules(_ schedules: [AutomationSchedule]) {
        self.schedules = schedules
    }

    func getSchedule(identifier: String) async throws -> AutomationSchedule? {
        throw AirshipErrors.error("Not implemented")

    }

    func getSchedule(identifier: String) async throws -> AutomationSchedule {
        throw AirshipErrors.error("Not implemented")
    }
    
    func getSchedules(group: String) async throws -> [AutomationSchedule] {
        throw AirshipErrors.error("Not implemented")
    }
    
    func scheduleConditionsChanged() {

    }
    

}
