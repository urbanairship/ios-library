/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class RemoteConfigTest: XCTestCase {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func testParseEmpty() throws {
        let json = "{}"

        let emptyConfig = try self.decoder.decode(RemoteConfig.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(emptyConfig, RemoteConfig())
    }

    func testJson() throws {
        let json = """
            {
               "metered_usage":{
                  "initial_delay_ms":100,
                  "interval_ms":200,
                  "enabled":true
               },
               "airship_config":{
                  "device_api_url":"device-api-url",
                  "analytics_url":"analytics-url",
                  "wallet_url":"wallet-url",
                  "remote_data_url":"remote-data-url",
                  "metered_usage_url":"metered-usage-url"
               },
               "contact_config":{
                  "max_cra_resolve_age_ms":300,
                  "foreground_resolve_interval_ms":400
               },
               "fetch_contact_remote_data":true
            }
        """

        let expected = RemoteConfig(
            airshipConfig: .init(
                remoteDataURL: "remote-data-url",
                deviceAPIURL: "device-api-url",
                analyticsURL: "analytics-url",
                meteredUsageURL: "metered-usage-url"
            ),
            meteredUsageConfig: .init(
                isEnabled: true,
                initialDelayMilliseconds: 100,
                intervalMilliseconds: 200
            ),
            fetchContactRemoteData: true,
            contactConfig: .init(
                foregroundIntervalMilliseconds: 400,
                channelRegistrationMaxResolveAgeMilliseconds: 300
            )
        )

        let config = try self.decoder.decode(RemoteConfig.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(config, expected)

        let roundTrip = try self.decoder.decode(RemoteConfig.self, from: try self.encoder.encode(expected))
        XCTAssertEqual(roundTrip, expected)
    }
}
