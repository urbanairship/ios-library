/* Copyright Airship and Contributors */

import Foundation

/// Represents a constraint on occurrences within a given time period.
struct FrequencyConstraint: Equatable, Hashable {
    
    /// The constraint identifier.
    private(set) var identifier: String
    
    /// The time range.
    private(set) var range: TimeInterval
    
    /// The number of allowed occurences.
    private(set) var count: UInt
    
    /// Frequency constraint initilizer.
    ///
    /// - Parameters:
    ///   - identifier: The constraint identifier.
    ///   - range: The time range.
    ///   - count: The number of allowed occurences.
    init(
        identifier: String,
        range: TimeInterval,
        count: UInt
    ) {
        self.identifier = identifier
        self.range = range
        self.count = count
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        return FrequencyConstraint(
            identifier: identifier,
            range: self.range,
            count: self.count)
    }

    static func == (
        lhs: FrequencyConstraint,
        rhs: FrequencyConstraint
    ) -> Bool {
        
        if (lhs.identifier != rhs.identifier) {
            return false
        }

        if (lhs.range != rhs.range) {
            return false
        }

        if (lhs.count != rhs.count) {
            return false
        }

        return true
    }

}
