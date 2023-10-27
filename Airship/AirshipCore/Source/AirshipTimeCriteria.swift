/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
public struct AirshipTimeCriteria: Codable, Sendable, Equatable {
    private let start: Int64?
    private let end: Int64?

    enum CodingKeys: String, CodingKey {
        case start = "start_timestamp"
        case end = "end_timestamp"
    }

    public init(start: Date? = nil, end: Date? = nil) {
        self.start = start?.millisecondsSince1970
        self.end = end?.millisecondsSince1970
    }
}

/// NOTE: For internal use only. :nodoc:
public extension AirshipTimeCriteria {
    func isActive(date: Date) -> Bool {
        let currentMS = date.millisecondsSince1970

        if let startMS = self.start, currentMS < startMS {
            return false
        }

        if let endMS = self.end, currentMS >= endMS {
            return false
        }

        return true
    }
}
