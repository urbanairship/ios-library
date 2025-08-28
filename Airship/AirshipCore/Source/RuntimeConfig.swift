/* Copyright Airship and Contributors */


import Combine

/// Airship config needed for runtime. Generated from `AirshipConfig` during takeOff.
public final class RuntimeConfig: Sendable {

    /// - NOTE: This option is reserved for internal debugging. :nodoc:
    public static let configUpdatedEvent = Notification.Name(
        "com.urbanairship.runtime_config_updated"
    )

    struct DefaultURLs {
        let deviceURL: String
        let analyticsURL: String
        let remoteDataURL: String

        static let us: DefaultURLs = DefaultURLs(
            deviceURL: "https://device-api.urbanairship.com",
            analyticsURL: "https://combine.urbanairship.com",
            remoteDataURL: "https://remote-data.urbanairship.com"
        )

        static let eu: DefaultURLs = DefaultURLs(
            deviceURL: "https://device-api.asnapieu.com",
            analyticsURL: "https://combine.asnapieu.com",
            remoteDataURL: "https://remote-data.asnapieu.com"
        )
    }

    /// The resolved app credentials.
    public let appCredentials: AirshipAppCredentials

    /// The request session used to perform authenticated interactions with the API
    public let requestSession: any AirshipRequestSession

    /// The airship config
    public let airshipConfig: AirshipConfig

    private let remoteConfigCache: RemoteConfigCache
    private let notificationCenter: NotificationCenter
    private let defaultURLs: DefaultURLs

    /// - NOTE: For internal use only. :nodoc:
    public var remoteConfig: RemoteConfig {
        return self.remoteConfigCache.remoteConfig
    }

    /// - NOTE: For internal use only. :nodoc:
    public var deviceAPIURL: String? {
        if let url = remoteConfig.airshipConfig?.deviceAPIURL {
            return url
        }

        guard !self.airshipConfig.requireInitialRemoteConfigEnabled else {
            return nil
        }

        return defaultURLs.deviceURL
    }

    /// - NOTE: For internal use only. :nodoc:
    var remoteDataAPIURL: String {
        if let url = remoteConfig.airshipConfig?.remoteDataURL {
            return url
        }

        if
            let initialConfigURL = airshipConfig.initialConfigURL?.normalizeURLString(),
            !initialConfigURL.isEmpty
        {
            return initialConfigURL
        }

        return defaultURLs.remoteDataURL
    }

    /// - NOTE: For internal use only. :nodoc:
    var analyticsURL: String? {
        if let url = remoteConfig.airshipConfig?.analyticsURL {
            return url
        }

        guard !self.airshipConfig.requireInitialRemoteConfigEnabled else {
            return nil
        }

        return defaultURLs.analyticsURL
    }

    /// - NOTE: For internal use only. :nodoc:
    var meteredUsageURL: String? {
        return remoteConfigCache.remoteConfig.airshipConfig?.meteredUsageURL
    }

    public convenience init(
        airshipConfig: AirshipConfig,
        appCredentials: AirshipAppCredentials,
        dataStore: PreferenceDataStore,
        notificationCenter: NotificationCenter = NotificationCenter.default
    ) {
        self.init(
            airshipConfig: airshipConfig,
            appCredentials: appCredentials,
            dataStore: dataStore,
            requestSession: DefaultAirshipRequestSession(
                appKey: appCredentials.appKey,
                appSecret: appCredentials.appSecret
            ),
            notificationCenter: notificationCenter
        )
    }

    init(
        airshipConfig: AirshipConfig,
        appCredentials: AirshipAppCredentials,
        dataStore: PreferenceDataStore,
        requestSession: any AirshipRequestSession,
        notificationCenter: NotificationCenter = NotificationCenter.default
    ) {
        self.airshipConfig = airshipConfig
        self.appCredentials = appCredentials
        self.requestSession = requestSession
        self.remoteConfigCache = RemoteConfigCache(dataStore: dataStore)
        self.notificationCenter = notificationCenter
        self.defaultURLs = switch(airshipConfig.site) {
        case .eu: DefaultURLs.eu
        case .us: DefaultURLs.us
        }
    }

    @MainActor
    func updateRemoteConfig(_ config: RemoteConfig) {
        let old = self.remoteConfig
        if config != old {
            self.remoteConfigCache.remoteConfig = config
            self.notificationCenter.post(
                name: RuntimeConfig.configUpdatedEvent,
                object: nil
            )

            self.remoteConfigListeners.value.forEach { listener in
                listener(old, config)
            }
        }
    }

    @MainActor
    func addRemoteConfigListener(
        notifyCurrent: Bool = true,
        listener: @MainActor @Sendable @escaping (RemoteConfig?, RemoteConfig) -> Void
    ) {
        if (notifyCurrent) {
            listener(nil, self.remoteConfig)
        }

        self.remoteConfigListeners.update { $0.append(listener) }
    }

    let remoteConfigListeners: AirshipMainActorValue<[@MainActor @Sendable (RemoteConfig?, RemoteConfig) -> Void]> = AirshipMainActorValue([])
}

extension String {
    fileprivate func normalizeURLString() -> String {
        guard hasSuffix("/") else {
            return self
        }
        var copy = self
        copy.removeLast()
        return copy
    }
}
