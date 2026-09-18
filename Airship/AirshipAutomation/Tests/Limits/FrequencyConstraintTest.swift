/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable @_spi(AirshipInternal) import AirshipAutomation

struct FrequencyConstraintTest {

    /// `Period` is a private nested type, so it can only be exercised through
    /// `FrequencyConstraint`'s `Decodable` conformance, which is how the SDK
    /// actually consumes it (remote-data payload -> `FrequencyConstraint.init(from:)`).
    private func decode(period: String, range: Double, boundary: UInt = 1) throws -> FrequencyConstraint {
        let json = """
        {
            "id": "test-id",
            "range": \(range),
            "period": "\(period)",
            "boundary": \(boundary)
        }
        """
        return try JSONDecoder().decode(FrequencyConstraint.self, from: Data(json.utf8))
    }

    @Test(arguments: [
        ("seconds", 1.0),
        ("minutes", 60.0),
        ("hours", 60.0 * 60.0),
        ("days", 60.0 * 60.0 * 24.0),
        ("weeks", 60.0 * 60.0 * 24.0 * 7.0),
        ("months", 60.0 * 60.0 * 24.0 * 30.0),
        ("years", 60.0 * 60.0 * 24.0 * 365.0),
    ] as [(String, Double)])
    func testPeriodToTimeInterval(period: String, expected: TimeInterval) throws {
        // A range of 1 isolates each period's per-unit conversion constant.
        let constraint = try decode(period: period, range: 1)
        #expect(constraint.range == expected)
    }

    @Test
    func testWeeksIsSevenDays() throws {
        // Regression coverage for MOBILE-5839: `.weeks` must convert using 7
        // days (604800s), not 6 (518400s), or weekly frequency limits
        // under-throttle by ~14.3%.
        let constraint = try decode(period: "weeks", range: 1)
        #expect(constraint.range == 604_800)
    }

    @Test
    func testMultiWeekRangeScalesLinearly() throws {
        let constraint = try decode(period: "weeks", range: 2)
        #expect(constraint.range == 1_209_600)
    }
}
