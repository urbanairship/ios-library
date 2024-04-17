/* Copyright Airship and Contributors */

/// NOTE: For internal use only. :nodoc:
public struct RemoteConfig: Codable, Equatable, Sendable {

    let airshipConfig: AirshipConfig?
    let meteredUsageConfig: MeteredUsageConfig?
    let fetchContactRemoteData: Bool?
    let contactConfig: ContactConfig?
    let disabledFeatures: AirshipFeature?
    public let iaaConfig: IAAConfig?

    var remoteDataRefreshInterval: TimeInterval? {
        return remoteDataRefreshIntervalMilliseconds?.timeInterval
    }

    let remoteDataRefreshIntervalMilliseconds: Int64?

    init(
        airshipConfig: AirshipConfig? = nil,
        meteredUsageConfig: MeteredUsageConfig? = nil,
        fetchContactRemoteData: Bool? = nil,
        contactConfig: ContactConfig? = nil,
        disabledFeatures: AirshipFeature? = nil,
        remoteDataRefreshIntervalMilliseconds: Int64? = nil,
        iaaConfig: IAAConfig? = nil
    ) {
        self.airshipConfig = airshipConfig
        self.meteredUsageConfig = meteredUsageConfig
        self.fetchContactRemoteData = fetchContactRemoteData
        self.contactConfig = contactConfig
        self.disabledFeatures = disabledFeatures
        self.remoteDataRefreshIntervalMilliseconds = remoteDataRefreshIntervalMilliseconds
        self.iaaConfig = iaaConfig
    }

    enum CodingKeys: String, CodingKey {
        case airshipConfig = "airship_config"
        case meteredUsageConfig = "metered_usage"
        case fetchContactRemoteData = "fetch_contact_remote_data"
        case contactConfig = "contact_config"
        case disabledFeatures = "disabled_features"
        case remoteDataRefreshIntervalMilliseconds = "remote_data_refresh_interval"
        case iaaConfig = "in_app_config"
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
    
    public struct IAAConfig: Codable, Equatable, Sendable {
        public let retryingQueue: RetryingQueueConfig?

        enum CodingKeys: String, CodingKey {
            case retryingQueue = "queue"
        }
    }
    
    public struct RetryingQueueConfig: Codable, Equatable, Sendable {
        public let maxConcurrentOperations: UInt?
        public let maxPendingResults: UInt?
        public let initialBackoff: TimeInterval?
        public let maxBackOff: TimeInterval?

        enum CodingKeys: String, CodingKey {
            case maxConcurrentOperations = "max_concurrent_operations"
            case maxPendingResults = "max_pending_results"
            case initialBackoff = "initial_back_off_seconds"
            case maxBackOff = "max_back_off_seconds"
        }
    }
}

fileprivate extension Int64 {
    var timeInterval: TimeInterval {
        Double(self)/1000
    }
}
