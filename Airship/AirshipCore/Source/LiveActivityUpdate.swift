/* Copyright Airship and Contributors */

import Foundation

/// An update to a live activity
struct LiveActivityUpdate: Codable, Equatable {
    enum Action: String, Codable {
        case set
        case remove
    }

    /// Update action
    var action: Action

    /// The activity's ID
    var id: String

    /// The app provided name
    var name: String

    /// The token, should be available on a set
    var token: String?

    /// The update start time in milliseconds
    var actionTimeMS: UInt64

    /// The activity start time in milliseconds
    var startTimeMS: UInt64

    enum CodingKeys: String, CodingKey {
        case action = "action"
        case id = "id"
        case name = "name"
        case token = "token"
        case actionTimeMS = "action_ts_ms"
        case startTimeMS = "start_ts_ms"
    }
}




