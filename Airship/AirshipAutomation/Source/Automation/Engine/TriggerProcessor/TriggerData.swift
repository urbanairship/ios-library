/* Copyright Airship and Contributors */



struct TriggerData: Sendable, Equatable, Codable {
    var scheduleID: String
    var triggerID: String

    var count: Double
    var children: [String: TriggerData]
    var lastTriggerableState: TriggerableState?

    init(
        scheduleID: String,
        triggerID: String,
        count: Double = 0.0,
        children: [String : TriggerData] = [:]
    ) {
        self.scheduleID = scheduleID
        self.triggerID = triggerID
        self.count = count
        self.children = children
    }
} 

extension TriggerData {
    mutating func incrementCount(_ value: Double) {
        self.count = self.count + value
    }

    mutating func resetCount() {
        self.count = 0
    }
}
