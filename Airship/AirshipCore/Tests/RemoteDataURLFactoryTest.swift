/* Copyright Airship and Contributors */

import XCTest
@testable
import AirshipCore

final class RemoteDataURLFactoryTest: XCTestCase {

    private let config: RuntimeConfig = RuntimeConfig.testConfig()

    func testURL() throws {
        let remoteDataURL = try! RemoteDataURLFactory.makeURL(
            config: config,
            path: "/some-path",
            locale: Locale(identifier: "en-US"),
            randomValue: 100
        )

        let sdkVersion = AirshipVersion.version
        XCTAssertEqual(
            "\(config.remoteDataAPIURL)/some-path?language=en&country=US&sdk_version=\(sdkVersion)&random_value=100",
            remoteDataURL.absoluteString
        )
    }

    func testURLNoCountry() throws {
        let remoteDataURL = try! RemoteDataURLFactory.makeURL(
            config: config,
            path: "/some-path",
            locale: Locale(identifier: "br"),
            randomValue: 100
        )

        let sdkVersion = AirshipVersion.version
        XCTAssertEqual(
            "\(config.remoteDataAPIURL)/some-path?language=br&sdk_version=\(sdkVersion)&random_value=100",
            remoteDataURL.absoluteString
        )
    }

}
