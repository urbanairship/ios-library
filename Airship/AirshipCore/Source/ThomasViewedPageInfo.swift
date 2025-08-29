/* Copyright Airship and Contributors */

import Foundation

/// - Note: for internal use only.  :nodoc:
public struct ThomasViewedPageInfo: Encodable, Sendable, Equatable, Hashable {
    public var identifier: String
    public var index: Int
    public var displayTime: TimeInterval

    public init(identifier: String, index: Int, displayTime: TimeInterval) {
        self.identifier = identifier
        self.index = index
        self.displayTime = displayTime
    }

    enum CodingKeys: String, CodingKey {
        case identifier = "page_identifier"
        case index = "page_index"
        case displayTime = "display_time"
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.identifier, forKey: .identifier)
        try container.encode(self.index, forKey: .index)

        try container.encode(
            String(format: "%.2f", displayTime),
            forKey: .displayTime
        )
    }
}
