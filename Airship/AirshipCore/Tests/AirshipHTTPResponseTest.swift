/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable
public import AirshipCore

public extension AirshipHTTPResponse {

    static func make(result: T?, statusCode: Int, headers: [String: String]) -> AirshipHTTPResponse<T> {
        return .init(result: result, statusCode: statusCode, headers: headers)
    }
}

@Suite struct AirshipHTTPResponseRetryAfterTest {

    // 2023-07-10T18:10:46Z
    private let now = Date(timeIntervalSince1970: 1689012646)

    private func response(retryAfter: String?) -> AirshipHTTPResponse<Void> {
        var headers: [String: String] = [:]
        if let retryAfter { headers["Retry-After"] = retryAfter }
        return AirshipHTTPResponse(result: nil, statusCode: 429, headers: headers)
    }

    // MARK: - Absence

    @Test
    func testNilWhenHeaderAbsent() {
        #expect(response(retryAfter: nil).retryAfter(now: now) == nil)
    }

    @Test
    func testNilWhenHeaderEmpty() {
        #expect(response(retryAfter: "").retryAfter(now: now) == nil)
    }

    @Test
    func testNilWhenHeaderWhitespace() {
        #expect(response(retryAfter: "   ").retryAfter(now: now) == nil)
    }

    // MARK: - delay-seconds

    @Test
    func testNumericSeconds() {
        #expect(120 == response(retryAfter: "120").retryAfter(now: now))
    }

    @Test
    func testFractionalSeconds() {
        #expect(1.5 == response(retryAfter: "1.5").retryAfter(now: now))
    }

    @Test
    func testZeroSeconds() {
        #expect(0 == response(retryAfter: "0").retryAfter(now: now))
    }

    @Test
    func testTrimsWhitespace() {
        #expect(120 == response(retryAfter: "  120  ").retryAfter(now: now))
    }

    @Test
    func testRejectsNegativeNumber() {
        // RFC 7231 §7.1.3 delay-seconds grammar excludes signed values.
        #expect(response(retryAfter: "-5").retryAfter(now: now) == nil)
    }

    @Test
    func testRejectsScientificNotation() {
        // Double parses "1e6", but it's outside the delay-seconds grammar.
        #expect(response(retryAfter: "1e6").retryAfter(now: now) == nil)
    }

    @Test
    func testRejectsLeadingPlus() {
        #expect(response(retryAfter: "+5").retryAfter(now: now) == nil)
    }

    @Test
    func testRejectsTrailingGarbage() {
        #expect(response(retryAfter: "120s").retryAfter(now: now) == nil)
    }

    // MARK: - HTTP-date (RFC 7231 §7.1.1.1)

    @Test
    func testHttpDateImfFixdate() {
        // 60 seconds after `now`.
        let value = "Mon, 10 Jul 2023 18:11:46 GMT"
        #expect(60 == response(retryAfter: value).retryAfter(now: now))
    }

    @Test
    func testHttpDateRfc850() {
        let value = "Monday, 10-Jul-23 18:11:46 GMT"
        #expect(60 == response(retryAfter: value).retryAfter(now: now))
    }

    @Test
    func testHttpDateAsctime() {
        let value = "Mon Jul 10 18:11:46 2023"
        #expect(60 == response(retryAfter: value).retryAfter(now: now))
    }

    @Test
    func testHttpDateInPastClampedToZero() {
        let value = "Mon, 10 Jul 2023 18:09:46 GMT"  // 60s before now
        #expect(0 == response(retryAfter: value).retryAfter(now: now))
    }

    // MARK: - ISO 8601 fallback

    @Test
    func testIso8601Date() {
        let value = "2023-07-10T18:11:46Z"  // 60s after now
        #expect(60 == response(retryAfter: value).retryAfter(now: now))
    }

    @Test
    func testIso8601DateInPastClampedToZero() {
        let value = "2023-07-10T18:09:46Z"  // 60s before now
        #expect(0 == response(retryAfter: value).retryAfter(now: now))
    }

    @Test
    func testIso8601ReturnsDeltaNotAbsoluteEpoch() {
        // Regression: previously returned `timeIntervalSince1970` (~1.7B seconds)
        // instead of the delta from now.
        let value = "2023-07-10T18:11:46Z"
        let result = response(retryAfter: value).retryAfter(now: now)
        #expect(result != nil)
        #expect(result! < 3600, "Should be a delta (~60s), not an absolute epoch")
    }

    // MARK: - Garbage

    @Test
    func testGarbageReturnsNil() {
        #expect(response(retryAfter: "what").retryAfter(now: now) == nil)
    }

    // MARK: - Case-insensitive header lookup

    @Test
    func testHeaderLookupIsCaseInsensitive() {
        // RFC 7230: header field names are case-insensitive.
        let lower = AirshipHTTPResponse<Void>(result: nil, statusCode: 429, headers: ["retry-after": "120"])
        #expect(120 == lower.retryAfter(now: now))

        let upper = AirshipHTTPResponse<Void>(result: nil, statusCode: 429, headers: ["RETRY-AFTER": "60"])
        #expect(60 == upper.retryAfter(now: now))
    }

    @Test
    func testLocationHeaderLookupIsCaseInsensitive() {
        let response = AirshipHTTPResponse<Void>(
            result: nil,
            statusCode: 307,
            headers: ["location": "https://example.com/redirect"]
        )
        #expect(URL(string: "https://example.com/redirect") == response.locationHeader)
    }
}
