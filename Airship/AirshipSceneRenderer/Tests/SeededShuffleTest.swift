/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable @_spi(AirshipInternal) import AirshipSceneRenderer

/// Pins the shared `randomize_children` algorithm to the vectors web tests against.
@Suite("Seeded shuffle")
struct SeededShuffleTest {

    @Test(
        "hashes a string's UTF-8 bytes with FNV-1a",
        arguments: [
            ("", 0x811c9dc5),
            ("a", 0xe40c292c),
            ("é", 0x1e9de8c1),
            ("日", 0x80d4e4fd),
            ("😀", 0x33a29608),
            ("ui-test:survey_options:5", 0x5eb9dae6),
        ] as [(String, UInt32)]
    )
    func fnv1a32(text: String, expected: UInt32) {
        #expect(SeededShuffle.fnv1a32(text) == expected)
    }

    @Test("draws the shared mulberry32 sequence from a hashed key")
    func mulberry32() {
        var next = SeededShuffle.Mulberry32(state: SeededShuffle.fnv1a32("ui-test:survey_options:5"))
        #expect([next(), next(), next(), next()] == [0x4d47218c, 0xaaab5a8b, 0xabecdff8, 0xbbd8a688])
    }

    @Test("builds the key from the seed, the identifier if any, and the count")
    func keyString() {
        #expect(SeededShuffle.keyString(count: 5, seed: "ui-test", identifier: "survey_options") == "ui-test:survey_options:5")
        #expect(SeededShuffle.keyString(count: 5, seed: "ui-test", identifier: nil) == "ui-test:5")
        #expect(SeededShuffle.keyString(count: 3, seed: "ui-test", identifier: "") == "ui-test:3")
    }

    @Test(
        "orders items by the seed, identifier and count",
        arguments: [
            ("ui-test", "survey_options", 5, [0, 4, 3, 2, 1]),
            ("ui-test", "survey_options", 6, [5, 0, 3, 4, 1, 2]),
            ("ui-test", "other_options", 5, [1, 0, 2, 3, 4]),
            ("seed-b", "survey_options", 5, [2, 0, 3, 4, 1]),
            ("ui-test", "first", 5, [4, 1, 0, 2, 3]),
            ("ui-test", "second", 5, [1, 0, 3, 2, 4]),
            ("ui-test", nil, 5, [1, 3, 2, 0, 4]),
            ("ui-test", "colors", 10, [6, 0, 4, 8, 3, 1, 2, 7, 5, 9]),
        ] as [(String, String?, Int, [Int])]
    )
    func order(seed: String, identifier: String?, count: Int, expected: [Int]) {
        #expect(SeededShuffle.order(count: count, seed: seed, identifier: identifier) == expected)
    }

    @Test("always returns a permutation of the item indices")
    func permutation() {
        for count in 0...40 {
            let order = SeededShuffle.order(count: count, seed: "s\(count)", identifier: "options")
            #expect(order.sorted() == Array(0..<count))
        }
    }

    @Test("gives every order of three items about equally often")
    func uniform() {
        let runs = 60000
        var counts: [[Int]: Int] = [:]
        for seed in 0..<runs {
            counts[SeededShuffle.order(count: 3, seed: "s\(seed)", identifier: nil), default: 0] += 1
        }
        #expect(counts.count == 6)
        for count in counts.values {
            #expect(abs(Double(count) / Double(runs) - 1.0 / 6.0) < 0.005)
        }
    }
}
