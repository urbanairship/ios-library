/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class AirshipUtilsTest: XCTestCase {
    func testSignedToken() throws {

        XCTAssertEqual(
            "VWtkZq18HZM3GWzD/q27qPSVszysSyoQfQ6tDEAcAko=",
            try! AirshipUtils.generateSignedToken(secret: "appSecret", tokenParams: ["appKey", "some channel"])
        )

        XCTAssertEqual(
            "Npyqy5OZxMEVv4bt64S3aUE4NwUQVLX50vGrEegohFE=",
            try! AirshipUtils.generateSignedToken(secret: "test-app-secret", tokenParams: ["test-app-key", "channel ID"])
        )
        
    }
}
