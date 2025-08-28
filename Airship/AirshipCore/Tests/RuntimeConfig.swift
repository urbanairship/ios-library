/* Copyright Airship and Contributors */



@testable
import AirshipCore

extension RuntimeConfig {
    class func testConfig(
        site: CloudSite = .us,
        useUserPreferredLocale: Bool = false,
        requireInitialRemoteConfigEnabled: Bool = false,
        initialConfigURL: String? = nil,
        notifiaconCenter: NotificationCenter = NotificationCenter()
    ) -> RuntimeConfig {
        let credentails = AirshipAppCredentials(
            appKey: UUID().uuidString,
            appSecret: UUID().uuidString
        )

        var airshipConfig = AirshipConfig()
        airshipConfig.site = site
        airshipConfig.useUserPreferredLocale = useUserPreferredLocale
        airshipConfig.initialConfigURL = initialConfigURL
        airshipConfig.requireInitialRemoteConfigEnabled = requireInitialRemoteConfigEnabled
        return RuntimeConfig(
            airshipConfig: airshipConfig,
            appCredentials: credentails,
            dataStore: PreferenceDataStore(appKey: credentails.appKey),
            requestSession: TestAirshipRequestSession(),
            notificationCenter: notifiaconCenter
        )
    }

    class func testConfig(
        airshipConfig: AirshipConfig,
        notifiaconCenter: NotificationCenter = NotificationCenter()
    ) -> RuntimeConfig {
        let credentails = AirshipAppCredentials(
            appKey: UUID().uuidString,
            appSecret: UUID().uuidString
        )

        return RuntimeConfig(
            airshipConfig: airshipConfig,
            appCredentials: credentails,
            dataStore: PreferenceDataStore(appKey: credentails.appKey),
            requestSession: TestAirshipRequestSession(),
            notificationCenter: notifiaconCenter
        )
    }
}
