/* Copyright Airship and Contributors */

import Foundation

/// The Config object provides an interface for passing common configurable values to `UAirship`.
/// The simplest way to use this class is to add an AirshipConfig.plist file in your app's bundle and set
/// the desired options.
public struct AirshipConfig: Decodable {

    /// The development app key. This should match the application on go.urbanairship.com that is
    /// configured with your development push certificate.
    public var developmentAppKey: String?

    /// The development app secret. This should match the application on go.urbanairship.com that is
    /// configured with your development push certificate.
    public var developmentAppSecret: String?

    /// The production app key. This should match the application on go.urbanairship.com that is
    /// configured with your production push certificate. This is used for App Store, Ad-Hoc and Enterprise
    /// app configurations.
    public var productionAppKey: String?

    /// The production app secret. This should match the application on go.urbanairship.com that is
    /// configured with your production push certificate. This is used for App Store, Ad-Hoc and Enterprise
    /// app configurations.
    public var productionAppSecret: String?

    /// The log level used for development apps. Defaults to `debug`.
    public var developmentLogLevel: AirshipLogLevel = .debug


    /// The log privacy level used for development apps. Allows logging to public console. Defaults to `private`.
    public var developmentLogPrivacyLevel: AirshipLogPrivacyLevel = .private
     

    /// The log level used for production apps. Defaults to `error`.
    public var productionLogLevel: AirshipLogLevel = .error

    /// The log privacy level used for production apps. Allows logging to public console. Defaults to `private`.
    public var productionLogPrivacyLevel: AirshipLogPrivacyLevel = .private

    /// Auto pause InAppAutomation on launch. Defaults to `false`
    public var autoPauseInAppAutomationOnLaunch: Bool = false
    
    /// Flag to enable or disable web view inspection on Airship created  web views. Applies only to iOS 16.4+.
    /// Defaults to `false`
    public var isWebViewInspectionEnabled: Bool = false
    
    /// Allows setting a custom closure for auth challenge certificate validation
    /// Defaults to `nil`
    public var connectionChallengeResolver: ChallengeResolveClosure? = nil
    
    /// A closure that can be used to manually recover the channel ID instead of having
    /// Airship recover or generate an ID automatically.
    ///
    /// This is a delicate API that should only be used if the application can ensure the channel ID was previously created and by recovering
    /// it will only be used by a single device. Having multiple devices with the same channel ID will cause unpredictable behavior.
    ///
    /// When the method is set to `restore`, the user must provide a previously generated, unique
    /// If the closure throws an error, Airship will delay channel registration until a successful execution.
    public var restoreChannelID: AirshipChannelCreateOptionClosure? = nil

    /// The airship cloud site. Defaults to `us`.
    public var site: CloudSite = .us
   
    /// Default enabled Airship features for the app. For more details, see `PrivacyManager`.
    /// Defaults to `all`.
    public var enabledFeatures: AirshipFeature = .all

    /// Allows resetting enabled features to match the runtime config defaults on each takeOff
    /// Defaults to `false`
    public var resetEnabledFeatures: Bool = false

    /// The default app key. Depending on the `inProduction` status,
    /// `developmentAppKey` or `productionAppKey` will take priority.
    public var defaultAppKey: String = ""

    /// The default app secret. Depending on the `inProduction` status,
    /// `developmentAppSecret` or `productionAppSecret` will take priority.
    public var defaultAppSecret: String = ""

    /// The production status of this application. This may be set directly, or it may be determined
    /// automatically if the `detectProvisioningMode` flag is set to `true`.
    /// If neither `inProduction` nor `detectProvisioningMode` is set,
    /// `detectProvisioningMode` will be enabled.
    public var inProduction: Bool {
        get {
            return detectProvisioningMode
            ? usesProductionPushServer() : _inProduction
        }
        set {
            _defaultProvisioningMode = false
            _inProduction = newValue
        }
    }

    /// Apps may be set to self-configure based on the APS-environment set in the
    /// embedded.mobileprovision file by using `detectProvisioningMode`. If
    /// `detectProvisioningMode` is set to `true`, the `inProduction` value will
    /// be determined at runtime by reading the provisioning profile. If it is set to
    /// `false` (the default), the inProduction flag may be set directly or by using the
    /// AirshipConfig.plist file.
    ///
    /// When this flag is enabled, the `inProduction` will fallback to `true` for safety
    /// so that the production keys will always be used if the profile cannot be read
    /// in a released app. Simulator builds do not include the profile, and the
    /// `detectProvisioningMode` flag does not have any effect in cases where a profile
    /// is not present. When a provisioning file is not present, the app will fall
    /// back to the `inProduction` property as set in code or the AirshipConfig.plist
    /// file.
    public var detectProvisioningMode: Bool {
        get {
            return _detectProvisioningMode ?? _defaultProvisioningMode
        }
        set {
            _detectProvisioningMode = newValue
        }
    }

    /// NOTE: For internal use only. :nodoc:
    public var profilePath: String?

    private var _inProduction = false
    private var _defaultProvisioningMode = true
    private var _detectProvisioningMode: Bool?

    /// If enabled, the Airship library automatically registers for remote notifications when push is enabled
    /// and intercepts incoming notifications in both the foreground and upon launch.
    ///
    /// Defaults to `true`. If this is disabled, you will need to register for remote notifications
    /// in application:didFinishLaunchingWithOptions: and forward all notification-related app delegate
    /// calls to UAPush and UAInbox.
    public var isAutomaticSetupEnabled: Bool = true

    /// An array of `UAURLAllowList` entry strings.
    /// This url allow list is used for validating which URLs can be opened or load the JavaScript native bridge.
    /// It affects landing pages, the open external URL and wallet actions,
    /// deep link actions (if a delegate is not set), and HTML in-app messages.
    ///
    /// - NOTE: See `UAURLAllowList` for pattern entry syntax.
    public var urlAllowList: [String] = [] {
        didSet {
            isURLAllowListSet = true
        }
    }

    var isURLAllowListSet: Bool = false

    /// An array of` UAURLAllowList` entry strings.
    /// This url allow list is used for validating which URLs can load the JavaScript native bridge,
    /// It affects Landing Pages, Message Center and HTML In-App Messages.
    ///
    /// - NOTE: See `UAURLAllowList` for pattern entry syntax.
    public var urlAllowListScopeJavaScriptInterface: [String] = []

    /// An array of UAURLAllowList entry strings.
    /// This url allow list is used for validating which URLs can be opened.
    /// It affects landing pages, the open external URL and wallet actions,
    /// deep link actions (if a delegate is not set), and HTML in-app messages.
    ///
    /// - NOTE: See `UAURLAllowList` for pattern entry syntax.
    public var urlAllowListScopeOpenURL: [String] = [] {
        didSet {
            isURLAllowListScopeOpenURLSet = true
        }
    }

    var isURLAllowListScopeOpenURLSet: Bool = false


    /// The iTunes ID used for Rate App Actions.
    public var itunesID: String?

    /// Toggles Airship analytics. Defaults to `true`. If set to `false`, many Airship features will not be
    /// available to this application.
    public var isAnalyticsEnabled: Bool = true

    /// The Airship default message center style configuration file.
    public var messageCenterStyleConfig: String?

    /// If set to `true`, the Airship user will be cleared if the application is
    /// restored on a different device from an encrypted backup.
    ///
    /// Defaults to `false`.
    public var clearUserOnAppRestore: Bool = false

    /// If set to `true`, the application will clear the previous named user ID on a
    /// re-install. Defaults to `false`.
    public var clearNamedUserOnAppRestore: Bool = false

    /// Flag indicating whether channel capture feature is enabled or not.
    ///
    /// Defaults to `true`.
    public var isChannelCaptureEnabled: Bool = true

    /// Flag indicating whether delayed channel creation is enabled. If set to `true` channel
    /// creation will not occur until channel creation is manually enabled.
    ///
    /// Defaults to `false`.
    public var isChannelCreationDelayEnabled: Bool = false

    /// Flag indicating whether extended broadcasts are enabled. If set to `true` the AirshipReady NSNotification
    /// will contain additional data: the channel identifier and the app key.
    ///
    /// Defaults to `false`.
    public var isExtendedBroadcastsEnabled: Bool = false

    /// If set to 'YES', the Airship SDK will request authorization to use
    /// notifications from the user. Apps that set this flag to `false` are
    /// required to request authorization themselves.
    ///
    /// Defaults to `true`.
    public var requestAuthorizationToUseNotifications: Bool = true

    /// If set to `true`, the SDK will wait for an initial remote config instead of falling back on default API URLs.
    ///
    /// Defaults to `true`.
    public var requireInitialRemoteConfigEnabled : Bool = true
    
    /// The Airship URL used to pull the initial config. This should only be set
    /// if you are using custom domains that forward to Airship.
    ///
    public var initialConfigURL: String?

    /// The Airship device API url.
    ///
    /// - Note: This option is reserved for internal debugging. :nodoc:
    public var deviceAPIURL: String?

    /// The Airship analytics API url.
    ///
    /// - Note: This option is reserved for internal debugging. :nodoc:
    public var analyticsURL: String?

    /// The Airship remote data API url.
    ///
    /// - Note: This option is reserved for internal debugging. :nodoc:
    public var remoteDataAPIURL: String?

    /// The Airship chat API URL.
    public var chatURL: String?

    /// The Airship web socket URL.
    public var chatWebSocketURL: String?

    /// If set to `true`, the SDK will use the preferred locale. Otherwise it will use the current locale.
    ///
    /// Defaults to `false`.
    public var useUserPreferredLocale : Bool = false

    /// If set to `true`, Message Center will attempt to be restored between reinstalls. If `false`,
    /// the Message Center user will be reset and the Channel will not be able to use the user
    /// as an identity hint to recover the past Channel ID.
    ///
    /// Defaults to `true`.
    public var restoreMessageCenterOnReinstall : Bool = true
    
    /// Airship log handler. All Airship log will be routed through the handler.
    ///
    /// The default logger will os.Logger on iOS 14+, and `print` on older devices.
    public var logHandler: (any AirshipLogHandler)? = nil
    
    /// Airship log level.
    /// Sets the Airship log level. The log level defaults to `.debug` in developer mode,
    /// and `.error` in production. Values set before `takeOff` will be overridden by
    /// the value from the AirshipConfig.
    private var customLogLevel: AirshipLogLevel? = nil
    public var logLevel: AirshipLogLevel {
        get { customLogLevel ?? (inProduction ? productionLogLevel : developmentLogLevel) }
        set { customLogLevel = newValue }
    }
    

    /// Returns the resolved app key.
    /// - Returns: The resolved app key or an empty string.
    public var appKey: String {
        let key = inProduction ? productionAppKey : developmentAppKey
        return key ?? defaultAppKey
    }

    /// Returns the resolved app secret.
    /// - Returns: The resolved app key or an empty string.
    public var appSecret: String {
        let secret = inProduction ? productionAppSecret : developmentAppSecret
        return secret ?? defaultAppSecret
    }
    
    /// Returns the resolved log privacy level.
    /// - Returns: The resolved log privacy level.
    public var logPrivacyLevel: AirshipLogPrivacyLevel {
        return inProduction ? productionLogPrivacyLevel : developmentLogPrivacyLevel
    }

    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    enum CodingKeys: String, CodingKey {
        case developmentAppKey
        case developmentAppSecret
        case productionAppKey
        case productionAppSecret
        case developmentLogLevel = "developmentLogLevel"
        case developmentLogPrivacyLevel = "developmentLogPrivacyLevel"
        case productionLogLevel = "productionLogLevel"
        case productionLogPrivacyLevel = "productionLogPrivacyLevel"
        case resetEnabledFeatures = "resetEnabledFeatures"
        case enabledFeatures = "enabledFeatures"
        case site = "site"
        case messageCenterStyleConfig
        case isExtendedBroadcastsEnabled = "isExtendedBroadcastsEnabled"
        case isChannelCreationDelayEnabled = "isChannelCreationDelayEnabled"
        case requireInitialRemoteConfigEnabled = "requireInitialRemoteConfigEnabled"
        case urlAllowListScopeOpenURL = "urlAllowListScopeOpenURL"
        case inProduction = "inProduction"
        case detectProvisioningMode = "detectProvisioningMode"
        case autoPauseInAppAutomationOnLaunch = "autoPauseInAppAutomationOnLaunch"
        case isWebViewInspectionEnabled = "isWebViewInspectionEnabled"
        case isAutomaticSetupEnabled = "isAutomaticSetupEnabled"
        case urlAllowList = "urlAllowList"
        case urlAllowListScopeJavaScriptInterface = "urlAllowListScopeJavaScriptInterface"
        case itunesID
        case isAnalyticsEnabled = "isAnalyticsEnabled"
        case clearUserOnAppRestore = "clearUserOnAppRestore"
        case clearNamedUserOnAppRestore = "clearNamedUserOnAppRestore"
        case isChannelCaptureEnabled = "isChannelCaptureEnabled"
        case requestAuthorizationToUseNotifications = "requestAuthorizationToUseNotifications"
        case initialConfigURL
        case deviceAPIURL
        case analyticsURL
        case remoteDataAPIURL
        case chatURL
        case chatWebSocketURL
        case useUserPreferredLocale = "useUserPreferredLocale"
        case restoreMessageCenterOnReinstall = "restoreMessageCenterOnReinstall"
        
        // legacy keys
        
        case developmentAppKeyLegacy = "DEVELOPMENT_APP_KEY"
        case developmentAppSecretLegacy = "DEVELOPMENT_APP_SECRET"
        case productionAppKeyLegacy = "PRODUCTION_APP_KEY"
        case productionAppSecretLegacy = "PRODUCTION_APP_SECRET"
        case inProductionLegacy = "APP_STORE_OR_AD_HOC_BUILD"
        case developmentLogLevelLegacy = "LOG_LEVEL"
    }
    /// Creates an instance using the values set in the `AirshipConfig.plist` file.
    /// - Returns: A config with values from `AirshipConfig.plist` file.
    public static func `default`() -> AirshipConfig {
        return AirshipConfig.config(
            contentsOfFile: Bundle.main.path(
                forResource: "AirshipConfig",
                ofType: "plist"
            )
        )
    }

    /**
     * Creates an instance using the values found in the specified `.plist` file.
     * - Parameter path: The path of the specified file.
     * - Returns: A config with values from the specified file.
     */
    public static func config(contentsOfFile path: String?) -> AirshipConfig {
        guard let path = path, let data = FileManager.default.contents(atPath: path) else {
            AirshipLogger.error("Failed to load contents of the plist file.")
            return AirshipConfig()
        }

        let decoder = PropertyListDecoder()

        var config = AirshipConfig()
        do {
            config = try decoder.decode(AirshipConfig.self, from: data)
        }
        catch {
            AirshipLogger.error("Unable to read event, deleting. \(error)")
        }
            
        return config
    }

    /// Creates an instance with empty values.
    /// - Returns: A config with empty values.
    public static func config() -> AirshipConfig {
        return AirshipConfig()
    }

    /// Creates an instance with empty values.
    /// - Returns: A Config with empty values.
    public init() {
        #if !targetEnvironment(macCatalyst)
        self.profilePath = Bundle.main.path(
            forResource: "embedded",
            ofType: "mobileprovision"
        )
        #else
        self.profilePath =
            URL(
                fileURLWithPath: URL(
                    fileURLWithPath: Bundle.main.resourcePath ?? ""
                )
                .deletingLastPathComponent().path
            )
            .appendingPathComponent("embedded.provisionprofile").path
        #endif
    }

    init(_ config: AirshipConfig) {
        developmentAppKey = config.developmentAppKey
        developmentAppSecret = config.developmentAppSecret
        productionAppKey = config.productionAppKey
        productionAppSecret = config.productionAppSecret
        defaultAppKey = config.defaultAppKey
        defaultAppSecret = config.defaultAppSecret
        deviceAPIURL = config.deviceAPIURL
        remoteDataAPIURL = config.remoteDataAPIURL
        initialConfigURL = config.initialConfigURL
        chatWebSocketURL = config.chatWebSocketURL
        chatURL = config.chatURL
        analyticsURL = config.analyticsURL
        site = config.site
        developmentLogLevel = config.developmentLogLevel
        developmentLogPrivacyLevel = config.developmentLogPrivacyLevel
        productionLogLevel = config.productionLogLevel
        productionLogPrivacyLevel = config.productionLogPrivacyLevel
        enabledFeatures = config.enabledFeatures
        resetEnabledFeatures = config.resetEnabledFeatures
        requestAuthorizationToUseNotifications =
            config.requestAuthorizationToUseNotifications
        requireInitialRemoteConfigEnabled =
            config.requireInitialRemoteConfigEnabled
        isAutomaticSetupEnabled = config.isAutomaticSetupEnabled
        isAnalyticsEnabled = config.isAnalyticsEnabled
        clearUserOnAppRestore = config.clearUserOnAppRestore
        urlAllowList = config.urlAllowList
        urlAllowListScopeJavaScriptInterface =
            config.urlAllowListScopeJavaScriptInterface
        urlAllowListScopeOpenURL = config.urlAllowListScopeOpenURL
        isURLAllowListSet = config.isURLAllowListSet
        isURLAllowListScopeOpenURLSet = config.isURLAllowListScopeOpenURLSet
        clearNamedUserOnAppRestore = config.clearNamedUserOnAppRestore
        isChannelCaptureEnabled = config.isChannelCaptureEnabled
        isChannelCreationDelayEnabled = config.isChannelCreationDelayEnabled
        isExtendedBroadcastsEnabled = config.isExtendedBroadcastsEnabled
        messageCenterStyleConfig = config.messageCenterStyleConfig
        itunesID = config.itunesID
        profilePath = config.profilePath
        _detectProvisioningMode = config.detectProvisioningMode
        _defaultProvisioningMode = config._defaultProvisioningMode
        _inProduction = config._inProduction
        autoPauseInAppAutomationOnLaunch = config.autoPauseInAppAutomationOnLaunch
        useUserPreferredLocale = config.useUserPreferredLocale
        restoreMessageCenterOnReinstall = config.restoreMessageCenterOnReinstall
        isWebViewInspectionEnabled = config.isWebViewInspectionEnabled
        connectionChallengeResolver = config.connectionChallengeResolver
        restoreChannelID = config.restoreChannelID
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let developmentAppKey = try container.decodeIfPresent(String.self, forKey: .developmentAppKey)
        if let developmentAppKey = developmentAppKey {
            self.developmentAppKey = developmentAppKey
        } else {
            self.developmentAppKey = try container.decodeIfPresent(String.self, forKey: .developmentAppKeyLegacy)
        }
        
        let developmentAppSecret = try container.decodeIfPresent(String.self, forKey: .developmentAppSecret)
        if let developmentAppSecret = developmentAppSecret {
            self.developmentAppSecret = developmentAppSecret
        } else {
            self.developmentAppSecret = try container.decodeIfPresent(String.self, forKey: .developmentAppSecretLegacy)
        }
        
        let productionAppKey = try container.decodeIfPresent(String.self, forKey: .productionAppKey)
        if let productionAppKey = productionAppKey {
            self.productionAppKey = productionAppKey
        } else {
            self.productionAppKey = try container.decodeIfPresent(String.self, forKey: .productionAppKeyLegacy)
        }
        
        let productionAppSecret = try container.decodeIfPresent(String.self, forKey: .productionAppSecret)
        if let productionAppSecret = productionAppSecret {
            self.productionAppSecret = productionAppSecret
        } else {
            self.productionAppSecret = try container.decodeIfPresent(String.self, forKey: .productionAppSecretLegacy)
        }
        
        let developmentLogLevel = try container.decodeIfPresent(AirshipLogLevel.self, forKey: .developmentLogLevel)
        if let developmentLogLevel = developmentLogLevel {
            self.developmentLogLevel = developmentLogLevel
        } else {
            self.developmentLogLevel = try container.decodeIfPresent(AirshipLogLevel.self, forKey: .developmentLogLevelLegacy) ?? .debug
        }
        
        self.productionLogLevel = try container.decodeIfPresent(AirshipLogLevel.self, forKey: .productionLogLevel) ?? .error
        self.developmentLogPrivacyLevel = try container.decodeIfPresent(AirshipLogPrivacyLevel.self, forKey: .developmentLogPrivacyLevel) ?? .private
        self.productionLogPrivacyLevel = try container.decodeIfPresent(AirshipLogPrivacyLevel.self, forKey: .productionLogPrivacyLevel) ?? .private
        self.resetEnabledFeatures = try container.decodeIfPresent(Bool.self, forKey: .resetEnabledFeatures) ?? false
        self.enabledFeatures = try container.decodeIfPresent(AirshipFeature.self, forKey: .enabledFeatures) ?? .all
        self.site = try container.decodeIfPresent(CloudSite.self, forKey: .site) ?? .us
        self.messageCenterStyleConfig = try container.decodeIfPresent(String.self, forKey: .messageCenterStyleConfig)
        self.isExtendedBroadcastsEnabled = try container.decodeIfPresent(Bool.self, forKey: .isExtendedBroadcastsEnabled) ?? false
        self.isChannelCreationDelayEnabled = try container.decodeIfPresent(Bool.self, forKey: .isChannelCreationDelayEnabled) ?? false
        self.requireInitialRemoteConfigEnabled = try container.decodeIfPresent(Bool.self, forKey: .requireInitialRemoteConfigEnabled) ?? true
        self.urlAllowListScopeOpenURL = try container.decodeIfPresent([String].self, forKey: .urlAllowListScopeOpenURL) ?? []
        
        let inProduction = try container.decodeIfPresent(Bool.self, forKey: .inProduction)
        if let inProduction = inProduction {
            self.inProduction = inProduction
        } else {
            self.inProduction = try container.decodeIfPresent(Bool.self, forKey: .inProductionLegacy) ?? (detectProvisioningMode
            ? usesProductionPushServer() : _inProduction)
        }
        
        self.detectProvisioningMode = try container.decodeIfPresent(Bool.self, forKey: .detectProvisioningMode) ?? true
        self.autoPauseInAppAutomationOnLaunch = try container.decodeIfPresent(Bool.self, forKey: .autoPauseInAppAutomationOnLaunch) ?? false
        self.isWebViewInspectionEnabled = try container.decodeIfPresent(Bool.self, forKey: .isWebViewInspectionEnabled) ?? false
        self.isAutomaticSetupEnabled = try container.decodeIfPresent(Bool.self, forKey: .isAutomaticSetupEnabled) ?? true
        self.urlAllowList = try container.decodeIfPresent([String].self, forKey: .urlAllowList) ?? []
        self.urlAllowListScopeJavaScriptInterface = try container.decodeIfPresent([String].self, forKey: .urlAllowListScopeJavaScriptInterface) ?? []
        self.itunesID = try container.decodeIfPresent(String.self, forKey: .itunesID)
        self.isAnalyticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .isAnalyticsEnabled) ?? true
        self.clearUserOnAppRestore = try container.decodeIfPresent(Bool.self, forKey: .clearUserOnAppRestore) ?? false
        self.clearNamedUserOnAppRestore = try container.decodeIfPresent(Bool.self, forKey: .clearNamedUserOnAppRestore) ?? false
        self.isChannelCaptureEnabled = try container.decodeIfPresent(Bool.self, forKey: .isChannelCaptureEnabled) ?? true
        self.requestAuthorizationToUseNotifications = try container.decodeIfPresent(Bool.self, forKey: .requestAuthorizationToUseNotifications) ?? true
        self.initialConfigURL = try container.decodeIfPresent(String.self, forKey: .initialConfigURL)
        self.deviceAPIURL = try container.decodeIfPresent(String.self, forKey: .deviceAPIURL)
        self.analyticsURL = try container.decodeIfPresent(String.self, forKey: .analyticsURL)
        self.remoteDataAPIURL = try container.decodeIfPresent(String.self, forKey: .remoteDataAPIURL)
        self.chatURL = try container.decodeIfPresent(String.self, forKey: .chatURL)
        self.chatWebSocketURL = try container.decodeIfPresent(String.self, forKey: .chatWebSocketURL)
        self.useUserPreferredLocale = try container.decodeIfPresent(Bool.self, forKey: .useUserPreferredLocale) ?? false
        self.restoreMessageCenterOnReinstall = try container.decodeIfPresent(Bool.self, forKey: .restoreMessageCenterOnReinstall) ?? true
    }

    public func copy(with zone: NSZone? = nil) -> Any {
        return AirshipConfig(self)
    }

    public var description: String {
        return String(
            format: """
                In Production (resolved): %d\n\
                In Production (as set): %d\n\
                Resolved App Key: %@\n\
                Resolved App Secret: %@\n\
                Resolved Log Level: %ld\n\
                Default App Key: %@\n\
                Default App Secret: %@\n\
                Development App Key: %@\n\
                Development App Secret: %@\n\
                Development Log Level: %ld\n\
                Development Log Privacy Level: %ld\n\
                Production App Key: %@\n\
                Production App Secret: %@\n\
                Production Log Level: %ld\n\
                Production Log Privacy Level: %ld\n\
                Detect Provisioning Mode: %d\n\
                Request Authorization To Use Notifications: %@\n\
                Require initial remote config: %@\n\
                Analytics Enabled: %d\n\
                Analytics URL: %@\n\
                Device API URL: %@\n\
                Remote Data API URL: %@\n\
                Initial config URL: %@\n\
                Automatic Setup Enabled: %d\n\
                Clear user on Application Restore: %d\n\
                URL Accepts List: %@\n\
                URL Accepts List Scope JavaScript Bridge : %@\n\
                URL Accepts List Scope Open : %@\n\
                Clear named user on App Restore: %d\n\
                Channel Capture Enabled: %d\n\
                Delay Channel Creation: %d\n\
                Extended broadcasts: %d\n\
                Default Message Center Style Config File: %@\n\
                Use iTunes ID: %@\n\
                Site:  %ld\n\
                Enabled features:  %ld\n\
                Reset enabled features:  %ld\n\
                Use user preferred locale: %d\n\
                Restore Message Center on reinstall:  %d\n\
                Web view insepection enabled:  %d\n
                """,
            inProduction,
            inProduction,
            appKey,
            appSecret,
            logLevel.rawValue,
            defaultAppKey,
            defaultAppSecret,
            developmentAppKey ?? "",
            developmentAppSecret ?? "",
            developmentLogLevel.rawValue,
            developmentLogPrivacyLevel.rawValue,
            productionAppKey ?? "",
            productionAppSecret ?? "",
            productionLogLevel.rawValue,
            productionLogPrivacyLevel.rawValue,
            detectProvisioningMode,
            requestAuthorizationToUseNotifications ? "YES" : "NO",
            requireInitialRemoteConfigEnabled ? "YES" : "NO",
            isAnalyticsEnabled,
            analyticsURL ?? "",
            deviceAPIURL ?? "",
            remoteDataAPIURL ?? "",
            initialConfigURL ?? "",
            isAutomaticSetupEnabled,
            clearUserOnAppRestore,
            urlAllowList,
            urlAllowListScopeJavaScriptInterface,
            urlAllowListScopeOpenURL,
            clearNamedUserOnAppRestore,
            isChannelCaptureEnabled,
            isChannelCreationDelayEnabled,
            isExtendedBroadcastsEnabled,
            messageCenterStyleConfig ?? "",
            itunesID ?? "",
            site.rawValue,
            enabledFeatures.rawValue,
            resetEnabledFeatures ? "YES" : "NO",
            useUserPreferredLocale,
            restoreMessageCenterOnReinstall ? "YES" : "NO",
            isWebViewInspectionEnabled ? "YES" : "NO"
        )
    }
    
    /// Validates the current configuration. In addition to performing a strict validation, this method
    /// will log warnings and common configuration errors.
    /// - Returns: `true` if the current configuration is valid, otherwise `false`.
    public func validate() -> Bool {
        validate(logIssues: true)
    }


    /// Validates the current configuration. In addition to performing a strict validation, this method
    /// will log warnings and common configuration errors.
    /// - Parameters:
    ///     - logIssues: `true` to log issues with the config,  otherwise `false`
    /// - Returns: `true` if the current configuration is valid, otherwise `false`.
    public func validate(logIssues: Bool) -> Bool {
        
        var valid = true

        //Check the format of the app key and password.
        //If they're missing or malformed, stop takeoff
        //and prevent the app from connecting to UA.
        let matchPred = NSPredicate(format: "SELF MATCHES %@", "^\\S{22}+$")

        if !matchPred.evaluate(with: developmentAppKey), logIssues {
            AirshipLogger.warn("Development App Key is not valid.")
        }

        if !matchPred.evaluate(with: developmentAppSecret), logIssues {
            AirshipLogger.warn("Development App Secret is not valid.")
        }

        if !matchPred.evaluate(with: productionAppKey), logIssues {
            AirshipLogger.warn("Production App Key is not valid.")
        }

        if !matchPred.evaluate(with: productionAppSecret), logIssues {
            AirshipLogger.warn("Production App Secret is not valid.")
        }

        if !matchPred.evaluate(with: appKey) {
            if (logIssues) {
                AirshipLogger.error("Current App Key \(appKey) is not valid.")
            }
            valid = false
        }

        if !matchPred.evaluate(with: appSecret) {
            if (logIssues) {
                AirshipLogger.error("Current App Secret \(appSecret) is not valid.")
            }
            valid = false
        }

        if developmentAppKey == productionAppKey, logIssues {
            AirshipLogger.warn(
                "Production App Key matches Development App Key."
            )
        }

        if developmentAppSecret == productionAppSecret, logIssues {
            AirshipLogger.warn(
                "Production App Secret matches Development App Secret."
            )
        }

        return valid
    }

    private static func coerceString(_ value: Any) -> String? {
        if let value = value as? String {
            return value
        }

        if let value = value as? Character {
            return String(value)
        }

        return nil
    }

    private static func coerceBool(_ value: Any) -> Bool? {
        if let value = value as? Bool {
            return value
        }

        if let value = value as? NSNumber {
            return value.boolValue
        }

        if let value = value as? String {
            let lowerCased = value.lowercased()
            if lowerCased == "true" || lowerCased == "yes" {
                return true
            } else if lowerCased == "false" || lowerCased == "no" {
                return false
            }
        }

        return nil
    }

    private static func coerceSite(_ value: Any) -> CloudSite? {
        if let site = value as? CloudSite {
            return site
        }

        if let rawValue = value as? Int {
            return CloudSite(rawValue: String(rawValue))
        }

        if let rawValue = value as? UInt {
            return CloudSite(rawValue: String(rawValue))
        }

        if let number = value as? NSNumber {
            return CloudSite(rawValue: number.stringValue)
        }

        if let string = value as? String {
            return CloudSiteNames(rawValue: string.lowercased())?.toSite()
        }

        return nil
    }

    private static func coerceLogLevel(_ value: Any) -> AirshipLogLevel? {
        if let logLevel = value as? AirshipLogLevel {
            return logLevel
        }

        if let rawValue = value as? Int {
            return AirshipLogLevel(rawValue: String(rawValue))
        }

        if let rawValue = value as? UInt {
            return AirshipLogLevel(rawValue: String(rawValue))
        }

        if let number = value as? NSNumber {
            return AirshipLogLevel(rawValue: number.stringValue)
        }

        if let string = value as? String {
            return AirshipLogLevel(rawValue: string.lowercased())
        }

        return nil
    }

    private static func coerceLogPrivacyLevel(_ value: Any) -> AirshipLogPrivacyLevel? {
        if let logPrivacyLevel = value as? AirshipLogPrivacyLevel {
            return logPrivacyLevel
        }

        if let rawValue = value as? Int {
            return AirshipLogPrivacyLevel(rawValue: String(rawValue))
        }

        if let rawValue = value as? UInt {
            return AirshipLogPrivacyLevel(rawValue: String(rawValue))
        }

        if let number = value as? NSNumber {
            return AirshipLogPrivacyLevel(rawValue: number.stringValue)
        }

        if let string = value as? String {
            return AirshipLogPrivacyLevel(rawValue: string.lowercased())
        }

        return nil
    }

    private static func coerceFeatures(_ value: Any) -> AirshipFeature? {
        if let features = value as? AirshipFeature {
            return features
        }

        var names: [String]?
        if let string = value as? String {
            names = string.components(separatedBy: ",")
        }

        if let array = value as? [String] {
            names = array
        }

        guard let names = names else {
            return nil
        }
        var features: AirshipFeature = []
        for name in names {
            guard
                let parsedFeatures = FeatureNames(rawValue: name.lowercased())?
                    .toFeatures()
            else {
                return nil
            }

            features.insert(parsedFeatures)
        }
        return features

    }

    /// NOTE: For internal use only. :nodoc:
    public static func isProductionProvisioningProfile(_ profilePath: String)
        -> Bool
    {
        AirshipLogger.trace("Profile path: \(profilePath)")

        guard
            let embeddedProfile: String = try? String(
                contentsOfFile: profilePath,
                encoding: .isoLatin1
            )
        else {
            AirshipLogger.info(
                "No mobile provision profile found or the profile could not be read. Defaulting to production mode."
            )
            return true
        }

        let scanner = Scanner(string: embeddedProfile)
        _ = scanner.scanUpToString("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
        guard let extractedPlist = scanner.scanUpToString("</plist>"),
            let plistData = extractedPlist.appending("</plist>")
                .data(using: .utf8),
            let plistDict = try? PropertyListSerialization.propertyList(
                from: plistData,
                options: [],
                format: nil
            ) as? [AnyHashable: Any]
        else {
            AirshipLogger.error(
                "Unable to read provision profile. Defaulting to production mode."
            )
            return true
        }

        guard
            let entitlements = plistDict["Entitlements"] as? [AnyHashable: Any]
        else {
            AirshipLogger.error(
                "Unable to read provision profile. Defaulting to production mode."
            )
            return true
        }

        // Tell the logs a little about the app
        if plistDict["ProvisionedDevices"] != nil {
            if (entitlements["get-task-allow"] as? Bool) == true {
                AirshipLogger.debug(
                    "Debug provisioning profile. Uses the APNS Sandbox Servers."
                )
            } else {
                AirshipLogger.debug(
                    "Ad-Hoc provisioning profile. Uses the APNS Production Servers."
                )
            }
        } else if (plistDict["ProvisionsAllDevices"] as? Bool) == true {
            AirshipLogger.debug(
                "Enterprise provisioning profile. Uses the APNS Production Servers."
            )
        } else {
            AirshipLogger.debug(
                "App Store provisioning profile. Uses the APNS Production Servers."
            )
        }

        let apsEnvironment = entitlements["aps-environment"] as? String

        if apsEnvironment == nil {
            AirshipLogger.warn(
                "aps-environment value is not set. If this is not a simulator, ensure that the app is properly provisioned for push"
            )
        }

        AirshipLogger.debug("APS Environment set to \(apsEnvironment ?? "")")
        return "development" != apsEnvironment
    }

    public func setValue(_ value: Any?, forUndefinedKey key: String) {
        switch key {
        case "openURLWhitelistingEnabled":
            AirshipLogger.warn(
                "The config key openURLWhitelistingEnabled has been removed. Use URLAllowListScopeJavaScriptInterface or URLAllowListScopeOpenURL instead"
            )
        case "dataCollectionOptInEnabled":
            AirshipLogger.warn(
                "The config key dataCollectionOptInEnabled has been removed. Use enabledFeatures instead."
            )

        default:
            break
        }

        AirshipLogger.debug("Ignoring invalid Config key: \(key)")
    }
    
    private func usesProductionPushServer() -> Bool {
        if let profilePath = self.profilePath, profilePath.count > 0,
           FileManager.default.fileExists(atPath: profilePath)
        {
            return AirshipConfig.isProductionProvisioningProfile(
                profilePath
            )
        } else {
            if self.isSimulator {
                AirshipLogger.error(
                    "No profile found for the simulator. Defaulting to inProduction flag: \(self._inProduction)"
                )
                return self._inProduction
            } else {
                AirshipLogger.error(
                    "No profile found, but not a simulator. Defaulting to inProduction = true"
                )
                return true
            }
        }
    }
}

// The Channel generation method. In `automatic` mode Airship will generate a new channelID and create a new channel.
// If the restore option is specified and `channelID` is a correct ID, Airship will try to restore a channel with the specified ID
public enum ChannelGenerationMethod {
    case automatic
    case restore(channelID: String)
}

public typealias AirshipChannelCreateOptionClosure = (() async throws -> ChannelGenerationMethod)

private enum LogPrivacyLevelNames: String {
    case `private`
    case `public`

    func toLogPrivacyLevel() -> AirshipLogPrivacyLevel {
        switch self {
        case .private:
            return AirshipLogPrivacyLevel.private
        case .public:
            return AirshipLogPrivacyLevel.public
        }
    }
}

private enum LogLevelNames: String {
    case undefined
    case none
    case error
    case warn
    case info
    case debug
    case trace
    case verbose

    func toLogLevel() -> AirshipLogLevel {
        switch self {
        case .undefined:
            return AirshipLogLevel.undefined
        case .debug:
            return AirshipLogLevel.debug
        case .none:
            return AirshipLogLevel.none
        case .error:
            return AirshipLogLevel.error
        case .warn:
            return AirshipLogLevel.warn
        case .info:
            return AirshipLogLevel.info
        case .verbose:
            return AirshipLogLevel.verbose
        case .trace:
            return AirshipLogLevel.verbose
        }
    }
}

private enum FeatureNames: String {
    case push
    case contacts
    case messageCenter = "message_center"
    case analytics
    case tagsAndAttributes = "tags_and_attributes"
    case inAppAutomation = "in_app_automation"
    case featureFlags = "feature_flags"
    case none
    case all

    func toFeatures() -> AirshipFeature {
        switch self {
        case .push: return .push
        case .contacts: return .contacts
        case .messageCenter: return .messageCenter
        case .analytics: return .analytics
        case .tagsAndAttributes: return .tagsAndAttributes
        case .inAppAutomation: return .inAppAutomation
        case .featureFlags: return .featureFlags
        case .none: return []
        case .all: return .all
        }
    }
}

private enum CloudSiteNames: String {
    case eu
    case us

    func toSite() -> CloudSite {
        switch self {
        case .eu:
            return CloudSite.eu
        case .us:
            return CloudSite.us
        }
    }
}
