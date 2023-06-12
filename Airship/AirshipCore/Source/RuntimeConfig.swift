/* Copyright Airship and Contributors */

import Foundation

/// Airship config needed for runtime. Generated from `UAConfig` during takeOff.
@objc(UARuntimeConfig)
public final class RuntimeConfig: NSObject, @unchecked Sendable {

    /// - NOTE: This option is reserved for internal debugging. :nodoc:
    @objc
    public static let configUpdatedEvent = Notification.Name(
        "com.urbanairship.runtime_config_updated"
    )

    // US
    private static let configUSDeviceAPIURL =
        "https://device-api.urbanairship.com"
    private static let configUSAnalyticsURL = "https://combine.urbanairship.com"
    private static let configUSRemoteDataAPIURL =
        "https://remote-data.urbanairship.com"

    // EU
    private static let configEUDeviceAPIURL = "https://device-api.asnapieu.com"
    private static let configEUAnalyticsURL = "https://combine.asnapieu.com"
    private static let configEURemoteDataAPIURL =
        "https://remote-data.asnapieu.com"

    /// The current app key (resolved using the inProduction flag).
    @objc
    public let appKey: String

    /// The current app secret (resolved using the inProduction flag).
    @objc
    public let appSecret: String

    /// The current default Airship log level.
    @objc
    public let logLevel: AirshipLogLevel

    /// The current default Airship log level.
    public let requestSession: AirshipRequestSession

    /// The production status of this application.
    @objc
    public let inProduction: Bool

    /// Auto pause InAppAutomation on launch.
    @objc
    public let autoPauseInAppAutomationOnLaunch: Bool

    /// If enabled, the Airship library automatically registers for remote notifications when push is enabled
    /// and intercepts incoming notifications in both the foreground and upon launch.
    ///
    /// Defaults to enabled. If this is disabled, you will need to register for remote notifications
    /// in application:didFinishLaunchingWithOptions: and forward all notification-related app delegate
    /// calls to UAPush and UAInbox.
    @objc
    public let isAutomaticSetupEnabled: Bool

    /// An array of UAURLAllowList entry strings.
    /// This url allow list is used for validating which URLs can be opened or load the JavaScript native bridge.
    /// It affects landing pages, the open external URL and wallet actions,
    /// deep link actions (if a delegate is not set), and HTML in-app messages.
    ///
    /// - NOTE: See UAURLAllowList for pattern entry syntax.
    @objc(URLAllowList)
    public let urlAllowList: [String]?

    let isURLAllowListSet: Bool
    let isURLAllowListScopeOpenURLSet: Bool

    /// An array of UAURLAllowList entry strings.
    /// This url allow list is used for validating which URLs can load the JavaScript native bridge.
    /// It affects Landing Pages, Message Center and HTML In-App Messages.
    ///
    /// - NOTE: See UAURLAllowList for pattern entry syntax.
    @objc(URLAllowListScopeJavaScriptInterface)
    public let urlAllowListScopeJavaScriptInterface: [String]?

    /// An array of UAURLAllowList entry strings.
    /// This url allow list is used for validating which URLs can be opened.
    /// It affects landing pages, the open external URL and wallet actions,
    /// deep link actions (if a delegate is not set), and HTML in-app messages.
    ///
    /// - NOTE: See UAURLAllowList for pattern entry syntax.
    @objc(URLAllowListScopeOpenURL)
    public let urlAllowListScopeOpenURL: [String]?


    /// Toggles Airship analytics. Defaults to `true`. If set to `false`, many Airship features will not be
    /// available to this application.
    @objc
    public let isAnalyticsEnabled: Bool

    /// The Airship default message center style configuration file.
    @objc
    public let messageCenterStyleConfig: String?

    /// The iTunes ID used for Rate App Actions.
    @objc
    public let itunesID: String?

    /// If set to `true`, the Airship user will be cleared if the application is
    /// restored on a different device from an encrypted backup.
    ///
    /// Defaults to `false`.
    @objc
    public let clearUserOnAppRestore: Bool

    /// If set to `true`, the application will clear the previous named user ID on a
    /// re-install. Defaults to `false`.
    @objc
    public let clearNamedUserOnAppRestore: Bool

    /// Flag indicating whether channel capture feature is enabled or not.
    ///
    /// Defaults to `false`.
    @objc
    public let isChannelCaptureEnabled: Bool

    /// Flag indicating whether delayed channel creation is enabled. If set to `true` channel
    /// creation will not occur until channel creation is manually enabled.
    ///
    /// Defaults to `false`.
    @objc
    public let isChannelCreationDelayEnabled: Bool

    /// Flag indicating whether extended broadcasts are enabled. If set to `true` the AirshipReady NSNotification
    /// will contain additional data: the channel identifier and the app key.
    ///
    /// Defaults to `false`.
    @objc
    public let isExtendedBroadcastsEnabled: Bool

    /// If set to 'YES', the Airship SDK will request authorization to use
    /// notifications from the user. Apps that set this flag to `false` are
    /// required to request authorization themselves.
    ///
    /// Defaults to `true`.
    @objc
    public let requestAuthorizationToUseNotifications: Bool

    /// If set to `true`, the SDK will wait for an initial remote config instead of falling back on default API URLs.
    ///
    /// Defaults to `false`.
    @objc
    public let requireInitialRemoteConfigEnabled: Bool

    /// Default enabled Airship features for the app. For more details, see PrivacyManager.
    /// Defaults to FeaturesAll.
    public let enabledFeatures: AirshipFeature

    private let site: CloudSite
    private let remoteConfigCache: RemoteConfigCache
    private let notificationCenter: NotificationCenter

    private let defaultDeviceAPIURL: String?

    /// - NOTE: This option is reserved for internal debugging. :nodoc:
    @objc
    public var deviceAPIURL: String? {
        let url =
            remoteConfigCache.remoteConfig?.deviceAPIURL
            ?? self.defaultDeviceAPIURL
        if url?.isEmpty == false {
            return url
        }

        guard !self.requireInitialRemoteConfigEnabled else {
            return nil
        }

        switch self.site {
        case .eu:
            return RuntimeConfig.configEUDeviceAPIURL
        case .us:
            return RuntimeConfig.configUSDeviceAPIURL
        @unknown default:
            return nil
        }
    }

    private let defaultRemoteDataAPIURL: String?
    private let defaultAnalyticsURL: String?
    private let defaultChatURL: String?
    private let defaultChatWebSocketURL: String?

    /// - NOTE: This option is reserved for internal debugging. :nodoc:
    @objc
    public var remoteDataAPIURL: String? {
        let url =
            remoteConfigCache.remoteConfig?.remoteDataURL
            ?? self.defaultRemoteDataAPIURL
        if url?.isEmpty == false {
            return url
        }

        switch self.site {
        case .eu:
            return RuntimeConfig.configEURemoteDataAPIURL
        case .us:
            return RuntimeConfig.configUSRemoteDataAPIURL
        @unknown default:
            return nil
        }
    }

    /// - NOTE: This option is reserved for internal debugging. :nodoc:
    @objc
    public var analyticsURL: String? {
        let url =
            remoteConfigCache.remoteConfig?.analyticsURL
            ?? self.defaultAnalyticsURL
        if url?.isEmpty == false {
            return url
        }

        guard !self.requireInitialRemoteConfigEnabled else {
            return nil
        }

        switch self.site {
        case .eu:
            return RuntimeConfig.configEUAnalyticsURL
        case .us:
            return RuntimeConfig.configUSAnalyticsURL
        @unknown default:
            return nil
        }
    }

    /// - NOTE: This option is reserved for internal debugging. :nodoc:
    @objc
    public var chatURL: String? {
        return self.remoteConfigCache.remoteConfig?.chatURL
            ?? self.defaultChatURL
    }

    /// - NOTE: This option is reserved for internal debugging. :nodoc:
    @objc
    public var chatWebSocketURL: String? {
        return self.remoteConfigCache.remoteConfig?.chatWebSocketURL
            ?? self.defaultChatWebSocketURL
    }

    @objc
    public convenience init(
        config: AirshipConfig,
        dataStore: PreferenceDataStore
    ) {
        self.init(
            config: config,
            dataStore: dataStore,
            requestSession: DefaultAirshipRequestSession(
                appKey: config.appKey,
                appSecret: config.appSecret
            )
        )
    }

    convenience init(
        config: AirshipConfig,
        dataStore: PreferenceDataStore,
        notificationCenter: NotificationCenter = NotificationCenter.default
    ) {
        self.init(
            config: config,
            dataStore: dataStore,
            requestSession: DefaultAirshipRequestSession(
                appKey: config.appKey,
                appSecret: config.appSecret
            ),
            notificationCenter: notificationCenter
        )
    }

    init(
        config: AirshipConfig,
        dataStore: PreferenceDataStore,
        requestSession: AirshipRequestSession,
        notificationCenter: NotificationCenter = NotificationCenter.default
    ) {
        self.requestSession = requestSession
        self.logLevel = config.logLevel
        self.appKey = config.appKey
        self.appSecret = config.appSecret
        self.inProduction = config.inProduction
        self.requestAuthorizationToUseNotifications =
            config.requestAuthorizationToUseNotifications
        self.requireInitialRemoteConfigEnabled =
            config.requireInitialRemoteConfigEnabled
        self.isAutomaticSetupEnabled = config.isAutomaticSetupEnabled
        self.isAnalyticsEnabled = config.isAnalyticsEnabled
        self.clearUserOnAppRestore = config.clearUserOnAppRestore
        self.urlAllowList = config.urlAllowList
        self.urlAllowListScopeJavaScriptInterface =
            config.urlAllowListScopeJavaScriptInterface
        self.urlAllowListScopeOpenURL = config.urlAllowListScopeOpenURL
        self.isURLAllowListSet = config.isURLAllowListSet
        self.isURLAllowListScopeOpenURLSet = config.isURLAllowListScopeOpenURLSet
        self.clearNamedUserOnAppRestore = config.clearNamedUserOnAppRestore
        self.isChannelCaptureEnabled = config.isChannelCaptureEnabled
        self.isChannelCreationDelayEnabled =
            config.isChannelCreationDelayEnabled
        self.isExtendedBroadcastsEnabled = config.isExtendedBroadcastsEnabled
        self.messageCenterStyleConfig = config.messageCenterStyleConfig
        self.itunesID = config.itunesID
        self.enabledFeatures = config.enabledFeatures
        self.site = config.site
        self.defaultAnalyticsURL = config.analyticsURL?.normalizeURLString()
        self.defaultDeviceAPIURL = config.deviceAPIURL?.normalizeURLString()
        self.autoPauseInAppAutomationOnLaunch = config.autoPauseInAppAutomationOnLaunch

        if let initialConfigURL = config.initialConfigURL {
            self.defaultRemoteDataAPIURL = initialConfigURL.normalizeURLString()
        } else {
            self.defaultRemoteDataAPIURL = config.remoteDataAPIURL?
                .normalizeURLString()
        }

        self.defaultChatURL = config.chatURL?.normalizeURLString()
        self.defaultChatWebSocketURL = config.chatWebSocketURL?
            .normalizeURLString()
        self.remoteConfigCache = RemoteConfigCache(dataStore: dataStore)
        self.notificationCenter = notificationCenter
        super.init()

        self.notificationCenter.addObserver(
            self,
            selector: #selector(remoteConfigUpdated(notification:)),
            name: RemoteConfigManager.remoteConfigUpdatedEvent,
            object: nil
        )
    }

    @objc
    private func remoteConfigUpdated(notification: Notification) {
        guard
            let config =
                notification.userInfo?[RemoteConfigManager.remoteConfigKey]
                as? RemoteConfig
        else {
            AirshipLogger.error("Missing remote config")
            return
        }

        if config != self.remoteConfigCache.remoteConfig {
            self.remoteConfigCache.remoteConfig = config
            self.notificationCenter.post(
                name: RuntimeConfig.configUpdatedEvent,
                object: nil
            )
        }
    }
}

extension String {
    fileprivate func normalizeURLString() -> String {
        var copy = self
        if copy.hasSuffix("/") {
            copy.removeLast()
        }
        return copy
    }
}
