/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipCore

final class AirshipConfigTest: XCTestCase {

    func testURLAllowListNotSetAfterCopy() throws {
        let config = AirshipConfig()
        let copy = config.copy() as! AirshipConfig
        XCTAssertFalse(copy.isURLAllowListSet)
        XCTAssertFalse(copy.isURLAllowListScopeOpenURLSet)
    }
    
    func testURLAllowListSetAfterCopy() throws {
        let config = AirshipConfig()
        config.urlAllowList = ["neat"]

        let copy = config.copy() as! AirshipConfig
        XCTAssertTrue(copy.isURLAllowListSet)
    }

    func testURLAllowScopeOpenURLSetListSetAfterCopy() throws {
        let config = AirshipConfig()
        config.urlAllowListScopeOpenURL = ["neat"]

        let copy = config.copy() as! AirshipConfig
        XCTAssertTrue(copy.isURLAllowListScopeOpenURLSet)
    }
}
