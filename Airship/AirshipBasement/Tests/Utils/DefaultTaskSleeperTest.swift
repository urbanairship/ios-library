/* Copyright Airship and Contributors */

import Testing
import Foundation

@_spi(AirshipInternal) @testable import AirshipBasement

struct DefaultTaskSleeperTest {
    private let date: UATestDate = UATestDate(dateOverride: Date())
    private let sleeps: SleepRecorder = SleepRecorder()
    private let sleeper: any AirshipTaskSleeper

    init() {
        sleeper = DefaultAirshipTaskSleeper(date: date) { [sleeps, date] interval in
            date.offset += interval
            await sleeps.append(interval)
        }
    }

    @Test
    func intervalSleep() async throws {
        try await sleeper.sleep(timeInterval: 85.0)
        let sleeps = await sleeps.values
        #expect(sleeps == [30.0, 30.0, 25.0])
    }

    @Test
    func belowIntervalSleep() async throws {
        try await sleeper.sleep(timeInterval: 30.0)
        let sleeps = await sleeps.values
        #expect(sleeps == [30.0])
    }

    @Test
    func negativeSleep() async throws {
        try await sleeper.sleep(timeInterval: -1.0)
        let sleeps = await sleeps.values
        #expect(sleeps == [])
    }

    @Test
    func noSleep() async throws {
        try await sleeper.sleep(timeInterval: 0.0)
        let sleeps = await sleeps.values
        #expect(sleeps == [])
    }
}

private actor SleepRecorder {
    private(set) var values: [TimeInterval] = []
    func append(_ interval: TimeInterval) {
        values.append(interval)
    }
}
