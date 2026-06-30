/* Copyright Airship and Contributors */

import Foundation

/// Lightweight replacement for `XCTestExpectation` for use inside Swift Testing
/// suites. Fulfillment is tracked in a thread-safe manner so it can be called
/// from `@Sendable` closures, and awaited via `fulfillment`.
final class AirshipTestExpectation: @unchecked Sendable {
    private let lock = NSLock()
    private var fulfillmentCount = 0
    private var _expectedFulfillmentCount: Int

    let description: String

    var expectedFulfillmentCount: Int {
        get { lock.withLock { _expectedFulfillmentCount } }
        set { lock.withLock { _expectedFulfillmentCount = newValue } }
    }

    init(description: String = "", expectedFulfillmentCount: Int = 1) {
        self.description = description
        self._expectedFulfillmentCount = expectedFulfillmentCount
    }

    func fulfill() {
        lock.withLock { fulfillmentCount += 1 }
    }

    var isFulfilled: Bool {
        lock.withLock { fulfillmentCount >= _expectedFulfillmentCount }
    }

    /// Awaits until the expectation has been fulfilled the expected number of
    /// times. Relies on the enclosing suite's `.timeLimit` to bound waiting.
    var fulfillment: Void {
        get async {
            while !isFulfilled {
                await Task.yield()
            }
        }
    }
}

/// Awaits fulfillment of the provided expectations, bounded by `timeout`.
func fulfillment(
    of expectations: [AirshipTestExpectation],
    timeout: TimeInterval = 10
) async {
    let deadline = Date().addingTimeInterval(timeout)
    for expectation in expectations {
        while !expectation.isFulfilled {
            if Date() > deadline { break }
            await Task.yield()
        }
    }
}
