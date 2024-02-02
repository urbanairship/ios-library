/* Copyright Airship and Contributors */

import Foundation

struct TriggerData: Sendable, Equatable, Codable {
    var scheduleID: String
    var triggerID: String
    var goal: Double
    
    var count: Double
    var children: [String: TriggerData]

    init(
        scheduleID: String,
        triggerID: String,
        goal: Double,
        count: Double,
        children: [String : TriggerData] = [:]
    ) {
        self.scheduleID = scheduleID
        self.triggerID = triggerID
        self.goal = goal
        self.count = count
        self.children = children
    }
}

extension TriggerData {
    var isGoalReached: Bool { return count >= goal && children.values.allSatisfy({ $0.isGoalReached }) }

    mutating func incrementCount(_ value: Double) {
        self.count = self.count + value
    }

    mutating func reset() {
        self.count = 0
    }

}
