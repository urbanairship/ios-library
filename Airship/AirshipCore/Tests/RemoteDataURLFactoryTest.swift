/* Copyright Airship and Contributors */

import Testing
@testable
import AirshipCore
import Foundation

@Suite
struct RemoteDataURLFactoryTest {

    private let config: RuntimeConfig = RuntimeConfig.testConfig()

    @Test
    func testURL() throws {
        let remoteDataURL = try! RemoteDataURLFactory.makeURL(
            config: config,
            path: "/some-path",
            locale: Locale(identifier: "en-US"),
            randomValue: 100
        )

        let sdkVersion = AirshipVersion.version
        #expect(
            "\(config.remoteDataAPIURL)/some-path?language=en&country=US&sdk_version=\(sdkVersion)&random_value=100" == remoteDataURL.absoluteString
        )
    }

    @Test
    func testURLNoCountry() throws {
        let remoteDataURL = try! RemoteDataURLFactory.makeURL(
            config: config,
            path: "/some-path",
            locale: Locale(identifier: "br"),
            randomValue: 100
        )

        let sdkVersion = AirshipVersion.version
        #expect(
            "\(config.remoteDataAPIURL)/some-path?language=br&sdk_version=\(sdkVersion)&random_value=100" == remoteDataURL.absoluteString
        )
    }

}
