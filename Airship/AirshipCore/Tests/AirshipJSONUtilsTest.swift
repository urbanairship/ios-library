/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

class JSONUtilsTest: XCTestCase {

    func testInvalidJSON() {

        do {
            _ = try AirshipJSONUtils.data(NSObject(), options: .prettyPrinted)
            XCTFail()
        } catch {}

    }

    func testValidJSON() throws {
        let _ = try AirshipJSONUtils.data(["Valid JSON object": true], options: .prettyPrinted)
    }
}
