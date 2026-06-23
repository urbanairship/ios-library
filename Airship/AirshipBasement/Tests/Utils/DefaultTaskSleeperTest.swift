/* Copyright Airship and Contributors */

import XCTest

@_spi(AirshipInternal) @testable import AirshipBasement

final class DefaultTaskSleeperTest: XCTestCase {
    private let date: UATestDate = UATestDate(dateOverride: Date())
    private let sleeps: SleepRecorder = SleepRecorder()
    private var sleeper: (any AirshipTaskSleeper)!

    override func setUp() async throws {
        sleeper = DefaultAirshipTaskSleeper(date: date) { [sleeps, date] interval in
            date.offset += interval
            await sleeps.append(interval)
        }
    }

    func testIntervalSleep() async throws {
        try await sleeper.sleep(timeInterval: 85.0)
        let sleeps = await sleeps.values
        XCTAssertEqual(sleeps, [30.0, 30.0, 25.0])
    }

    func testBelowIntervalSleep() async throws {
        try await sleeper.sleep(timeInterval: 30.0)
        let sleeps = await sleeps.values
        XCTAssertEqual(sleeps, [30.0])
    }

    func testNegativeSleep() async throws {
        try await sleeper.sleep(timeInterval: -1.0)
        let sleeps = await sleeps.values
        XCTAssertEqual(sleeps, [])
    }

    func testNoSleep() async throws {
        try await sleeper.sleep(timeInterval: 0.0)
        let sleeps = await sleeps.values
        XCTAssertEqual(sleeps, [])
    }
}

private actor SleepRecorder {
    private(set) var values: [TimeInterval] = []
    func append(_ interval: TimeInterval) {
        values.append(interval)
    }
}
