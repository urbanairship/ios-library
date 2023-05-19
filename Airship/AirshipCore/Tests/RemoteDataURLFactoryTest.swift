/* Copyright Airship and Contributors */

import XCTest
@testable
import AirshipCore

final class RemoteDataURLFactoryTest: XCTestCase {

    let runtimeConfig: RuntimeConfig = {
        let airshipConfig = AirshipConfig()
        airshipConfig.remoteDataAPIURL = "https://example.com"

        return RuntimeConfig(
            config: airshipConfig,
            dataStore: PreferenceDataStore(appKey: UUID().uuidString),
            notificationCenter: NotificationCenter()
        )
    }()

    func testURL() throws {
        let remoteDataURL = try! RemoteDataURLFactory.makeURL(
            config: runtimeConfig,
            path: "/some-path",
            locale: Locale(identifier: "en-US"),
            randomValue: 100
        )
        XCTAssertEqual(
            "https://example.com/some-path?language=en&country=US&sdk_version=17.0.0&random_value=100",
            remoteDataURL.absoluteString
        )
    }

    func testURLNoCountry() throws {
        let remoteDataURL = try! RemoteDataURLFactory.makeURL(
            config: runtimeConfig,
            path: "/some-path",
            locale: Locale(identifier: "br"),
            randomValue: 100
        )
        XCTAssertEqual(
            "https://example.com/some-path?language=br&sdk_version=17.0.0&random_value=100",
            remoteDataURL.absoluteString
        )
    }

}
