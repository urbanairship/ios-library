/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class DefaultTaskSleeperTest: XCTestCase {
    private let date: UATestDate = UATestDate(dateOverride: Date())
    private let sleeps: AirshipActorValue<[TimeInterval]> = AirshipActorValue([])
    private var sleeper: AirshipTaskSleeper!

    override func setUp() async throws {
        sleeper = DefaultAirshipTaskSleeper(date: date) { [sleeps, date] interval in
            date.offset += interval
            await sleeps.update { current in
                current.append(interval)
            }
        }
    }

    func testIntervalSleep() async throws {
        try await sleeper.sleep(timeInterval: 85.0)
        let sleeps = await sleeps.value
        XCTAssertEqual(sleeps, [30.0, 30.0, 25.0])
    }

    func testBelowIntervalSleep() async throws {
        try await sleeper.sleep(timeInterval: 30.0)
        let sleeps = await sleeps.value
        XCTAssertEqual(sleeps, [30.0])
    }

    func testNegativeSleep() async throws {
        try await sleeper.sleep(timeInterval: -1.0)
        let sleeps = await sleeps.value
        XCTAssertEqual(sleeps, [])
    }

    func testNoSleep() async throws {
        try await sleeper.sleep(timeInterval: 0.0)
        let sleeps = await sleeps.value
        XCTAssertEqual(sleeps, [])
    }
}
