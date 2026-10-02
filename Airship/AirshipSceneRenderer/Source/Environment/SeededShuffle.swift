/* Copyright Airship and Contributors */

import Foundation

/// The `randomize_children` shuffle every platform implements step for step, so one key gives one order everywhere.
///
/// FNV-1a over the key's UTF-8 bytes seeds mulberry32, which drives a Fisher–Yates shuffle. The
/// key is `<seed>:<identifier>:<count>`, or `<seed>:<count>` without an identifier: seed `ui-test`,
/// identifier `survey_options` and 5 items give `ui-test:survey_options:5`, which orders the items
/// `0, 4, 3, 2, 1`.
enum SeededShuffle {

    /// The seed UI tests pass, so screenshot baselines hold from run to run and compare across platforms.
    static let uiTestSeed: String = "ui-test"

    /// Item indices in the shuffled order a key gives, the same on every call and every platform.
    ///
    /// - Parameters:
    ///   - count: how many items the layout has, hidden ones included
    ///   - seed: the scene's seed
    ///   - identifier: the layout's identifier, if it has one; empty reads as none
    /// - Returns: `0..<count` in shuffled order
    static func order(count: Int, seed: String, identifier: String?) -> [Int] {
        var indices = Array(0..<count)
        var next = Mulberry32(state: fnv1a32(keyString(count: count, seed: seed, identifier: identifier)))
        var i = indices.count - 1
        while i > 0 {
            // UInt64 so the product can't overflow; web computes the same index exactly in a double.
            let j = Int((UInt64(next()) &* UInt64(i + 1)) >> 32)
            indices.swapAt(i, j)
            i -= 1
        }
        return indices
    }

    /// Builds the string a shuffle is hashed from.
    ///
    /// - Parameters:
    ///   - count: how many items are shuffled
    ///   - seed: the scene's seed
    ///   - identifier: the layout's identifier, if it has one; empty reads as none
    /// - Returns: `<seed>:<identifier>:<count>`, or `<seed>:<count>` without an identifier
    static func keyString(count: Int, seed: String, identifier: String?) -> String {
        [seed, identifier, String(count)]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ":")
    }

    /// The FNV-1a 32-bit hash of a string's UTF-8 bytes.
    ///
    /// - Parameter text: the string to hash
    /// - Returns: the hash
    static func fnv1a32(_ text: String) -> UInt32 {
        var hash: UInt32 = 0x811c9dc5
        for byte in text.utf8 {
            hash = (hash ^ UInt32(byte)) &* 0x01000193
        }
        return hash
    }

    /// A mulberry32 generator: each call returns the next 32-bit draw.
    struct Mulberry32 {
        private var a: UInt32

        init(state: UInt32) {
            self.a = state
        }

        mutating func callAsFunction() -> UInt32 {
            a &+= 0x6d2b79f5
            var t = (a ^ (a >> 15)) &* (1 | a)
            t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
            return t ^ (t >> 14)
        }
    }
}

/// How a layout's items are ordered for placement and reading.
enum ItemOrder {

    /// Sorts item indices by ascending `order`, keeping `base` order among equal ones.
    ///
    /// `base` is the list order, or the `randomize_children` shuffle, so shuffling mixes only items of
    /// one order: a "None of these" at `order: 1` stays last.
    ///
    /// - Parameters:
    ///   - base: item indices in list or shuffled order
    ///   - orders: each item's resolved `order`, by item index; `nil` is 0
    /// - Returns: the item indices in placement order
    static func sorted(_ base: [Int], orders: [Double?]) -> [Int] {
        base.enumerated()
            .sorted { lhs, rhs in
                let lhsOrder = orders[lhs.element] ?? 0
                let rhsOrder = orders[rhs.element] ?? 0
                return lhsOrder != rhsOrder ? lhsOrder < rhsOrder : lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}
