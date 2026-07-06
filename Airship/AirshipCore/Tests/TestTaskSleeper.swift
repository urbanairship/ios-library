@_spi(AirshipInternal) public import AirshipCore
public import Foundation
@_spi(AirshipInternal) import AirshipBasement

/// Test sleeper that records each `sleep` call and optionally parks until released.
///
/// Default mode: every `sleep` returns immediately after recording. Call `pause()` to make
/// subsequent sleeps park on a continuation until `resume()` is called.
///
/// Use `waitForSleep(_:)` to await a specific interval being recorded.
@_spi(AirshipInternal)
public actor TestTaskSleeper: AirshipTaskSleeper {
    public var sleeps: [TimeInterval] = []
    private var updates: AirshipAsyncChannel<[TimeInterval]> = AirshipAsyncChannel()
    public var continuations: [CheckedContinuation<Void, Never>] = []
    private var observers: [(@Sendable ([TimeInterval]) -> Bool, CheckedContinuation<Void, Never>)] = []
    private var isPaused: Bool = false

    public init() {}

    public func pause() {
        self.isPaused = true
    }

    public func resume() {
        self.isPaused = false
        continuations.forEach { $0.resume() }
        continuations.removeAll()
    }

    public var sleepUpdates: AsyncStream<[TimeInterval]> {
        get async {
            await updates.makeStream()
        }
    }

    /// Resolves once `sleeps` contains `interval`.
    public func waitForSleep(_ interval: TimeInterval) async {
        if sleeps.contains(interval) { return }
        await withCheckedContinuation { continuation in
            observers.append(({ $0.contains(interval) }, continuation))
        }
    }

    public func sleep(timeInterval: TimeInterval) async throws {
        sleeps.append(timeInterval)
        await updates.send(sleeps)

        var remaining: [(@Sendable ([TimeInterval]) -> Bool, CheckedContinuation<Void, Never>)] = []
        for entry in observers {
            if entry.0(sleeps) {
                entry.1.resume()
            } else {
                remaining.append(entry)
            }
        }
        observers = remaining

        if isPaused {
            await withCheckedContinuation { continuation in
                continuations.append(continuation)
            }
        }
    }
}
