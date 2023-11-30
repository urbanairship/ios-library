/* Copyright Airship and Contributors */

/// NOTE: For internal use only. :nodoc:
struct RemoteConfig: Codable, Equatable, Sendable {

    let airshipConfig: AirshipConfig?
    let meteredUsageConfig: MeteredUsageConfig?
    let fetchContactRemoteData: Bool?
    let contactConfig: ContactConfig?

    init(
        airshipConfig: AirshipConfig? = nil,
        meteredUsageConfig: MeteredUsageConfig? = nil,
        fetchContactRemoteData: Bool? = nil,
        contactConfig: ContactConfig? = nil
    ) {
        self.airshipConfig = airshipConfig
        self.meteredUsageConfig = meteredUsageConfig
        self.fetchContactRemoteData = fetchContactRemoteData
        self.contactConfig = contactConfig
    }

    enum CodingKeys: String, CodingKey {
        case airshipConfig = "airship_config"
        case meteredUsageConfig = "metered_usage_config"
        case fetchContactRemoteData = "fetch_contact_remote_data"
        case contactConfig = "contact_config"
    }

    struct ContactConfig: Codable, Equatable, Sendable {
        let foregroundIntervalMilliseconds: Int64?
        let channelRegistrationMaxResolveAgeMilliseconds: Int64?

        var foregroundInterval: TimeInterval? {
            return foregroundIntervalMilliseconds?.timeInterval
        }

        var channelRegistrationMaxResolveAge: TimeInterval? {
            return channelRegistrationMaxResolveAgeMilliseconds?.timeInterval
        }

        enum CodingKeys: String, CodingKey {
            case foregroundIntervalMilliseconds = "foreground_resolve_interval_ms"
            case channelRegistrationMaxResolveAgeMilliseconds = "max_cra_resolve_age_ms"
        }
    }

    struct MeteredUsageConfig: Codable, Equatable, Sendable {
        let isEnabled: Bool?
        let initialDelayMilliseconds: Int64?
        let intervalMilliseconds: Int64?

        var intialDelay: TimeInterval? {
            return initialDelayMilliseconds?.timeInterval
        }

        var interval: TimeInterval? {
            return intervalMilliseconds?.timeInterval
        }

        enum CodingKeys: String, CodingKey {
            case isEnabled = "enabled"
            case initialDelayMilliseconds = "initial_delay_ms"
            case intervalMilliseconds = "interval_ms"
        }
    }

    struct AirshipConfig: Codable, Equatable, Sendable {
        public let remoteDataURL: String?
        public let deviceAPIURL: String?
        public let analyticsURL: String?
        public let meteredUsageURL: String?

        enum CodingKeys: String, CodingKey {
            case remoteDataURL = "remote_data_url"
            case deviceAPIURL = "device_api_url"
            case analyticsURL = "analytics_url"
            case meteredUsageURL = "metered_usage_url"
        }
    }
}

fileprivate extension Int64 {
    var timeInterval: TimeInterval {
        Double(self)/1000
    }
}
