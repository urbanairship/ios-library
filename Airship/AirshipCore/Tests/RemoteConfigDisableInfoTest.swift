/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

class RemoteConfigDisableInfoTest: XCTestCase {

    func testParse() throws {
        let json: [String : Any] = [
               "modules": ["push", "message_center"],
               "app_versions": [ "value": ["version_matches": "+" ], "scope": ["ios", "version"] ],
               "sdk_versions": ["1.0.0", "[1.0,99.0["],
               "remote_data_refresh_interval": 100 ]

        let disableInfo = RemoteConfigDisableInfo(json: json)
        let expectedModules = [RemoteConfigModule.push, RemoteConfigModule.messageCenter]
        XCTAssertEqual(expectedModules, disableInfo?.disableModules)
        XCTAssertEqual(100.0, disableInfo?.remoteDataRefreshInterval)
        XCTAssertNotNil(disableInfo?.appVersionConstraint)
        XCTAssertEqual(2, disableInfo?.sdkVersionConstraints.count)
    }

    func testParseAll() throws {
        let json: [String : Any] = [ "modules": "all" ]
        let disableInfo = RemoteConfigDisableInfo(json: json)
        let expectedModules = RemoteConfigModule.allCases
        XCTAssertEqual(expectedModules, disableInfo?.disableModules)
    }
}
