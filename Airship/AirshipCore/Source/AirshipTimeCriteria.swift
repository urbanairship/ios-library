/* Copyright Airship and Contributors */

public import Foundation
@_spi(AirshipInternal) import AirshipBasement

/// - Note: For internal use only. :nodoc:
public struct AirshipTimeCriteria: Codable, Sendable, Equatable {
    private let start: Int64?
    private let end: Int64?

    enum CodingKeys: String, CodingKey {
        case start = "start_timestamp"
        case end = "end_timestamp"
    }

    public init(start: Date? = nil, end: Date? = nil) {
        self.start = start?.airshipMillisecondsSince1970
        self.end = end?.airshipMillisecondsSince1970
    }
}

/// - Note: For internal use only. :nodoc:
public extension AirshipTimeCriteria {
    func isActive(date: Date) -> Bool {
        let currentMS = date.airshipMillisecondsSince1970

        if let startMS = self.start, currentMS < startMS {
            return false
        }

        if let endMS = self.end, currentMS >= endMS {
            return false
        }

        return true
    }
}
