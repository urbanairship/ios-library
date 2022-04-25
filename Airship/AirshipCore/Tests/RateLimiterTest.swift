/* Copyright Airship and Contributors */

import XCTest
@testable
import AirshipCore

class RateLimiterTest: XCTestCase {
    let testDate = UATestDate(offset: 0, dateOverride: Date())
    lazy var rateLimiter: RateLimiter = {
        return RateLimiter(date: testDate)
    }()

    func testRateLimit() throws {
        // 3 per second
        try! rateLimiter.set("foo", rate: 3, timeInterval: 1)
        rateLimiter.status("foo")!.assertWithinLimit(3)

        rateLimiter.track("foo")
        rateLimiter.status("foo")!.assertWithinLimit(2)

        self.testDate.offset = 0.1
        rateLimiter.track("foo")
        rateLimiter.status("foo")!.assertWithinLimit(1)

        self.testDate.offset = 0.2
        rateLimiter.track("foo")
        rateLimiter.status("foo")!.assertOverLimit(0.8)

        self.testDate.offset = 0.8
        rateLimiter.status("foo")!.assertOverLimit(0.2)

        self.testDate.offset = 1.0
        rateLimiter.status("foo")!.assertWithinLimit(1)

        self.testDate.offset = 1.1
        rateLimiter.status("foo")!.assertWithinLimit(2)

        self.testDate.offset = 1.2
        rateLimiter.status("foo")!.assertWithinLimit(3)

        self.testDate.offset = 10
        rateLimiter.status("foo")!.assertWithinLimit(3)
    }

    func testInvalidRateLimitThrows() throws {
        XCTAssertThrowsError(try rateLimiter.set("foo", rate: 1, timeInterval: 0))
        XCTAssertThrowsError(try rateLimiter.set("foo", rate: 0, timeInterval: 1.0))
    }

    func testRateLimitOverTrack() throws {
        try! rateLimiter.set("foo", rate: 1, timeInterval: 10)
        rateLimiter.status("foo")!.assertWithinLimit(1)

        rateLimiter.track("foo")
        rateLimiter.status("foo")!.assertOverLimit(10)

        self.testDate.offset = 8
        rateLimiter.status("foo")!.assertOverLimit(2)

        rateLimiter.track("foo")
        rateLimiter.track("foo")
        rateLimiter.status("foo")!.assertOverLimit(10)

        self.testDate.offset = 9
        rateLimiter.track("foo")
        rateLimiter.status("foo")!.assertOverLimit(10)

        self.testDate.offset = 19
        rateLimiter.status("foo")!.assertWithinLimit(1)
    }

    func testMulitpleRules() throws {
        try! rateLimiter.set("foo", rate: 1, timeInterval: 10)
        try! rateLimiter.set("bar", rate: 4, timeInterval: 3)

        rateLimiter.status("foo")!.assertWithinLimit(1)
        rateLimiter.status("bar")!.assertWithinLimit(4)

        rateLimiter.track("foo")
        rateLimiter.status("foo")!.assertOverLimit(10.0)
        rateLimiter.status("bar")!.assertWithinLimit(4)

        rateLimiter.track("bar")
        rateLimiter.status("foo")!.assertOverLimit(10.0)
        rateLimiter.status("bar")!.assertWithinLimit(3)
    }
}

extension RateLimiter.Status {
    func assertWithinLimit(_ expected: Int) {
        switch(self) {
        case .withinLimit(let count):
            XCTAssertEqual(expected, count)
        default:
            XCTFail()
        }
    }

    func assertOverLimit(_ expected: TimeInterval) {
        switch(self) {
        case .overLimit(let next):
            XCTAssertEqual(expected, next, accuracy: 0.001)
        default:
            XCTFail()
        }
    }
}
