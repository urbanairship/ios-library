/* Copyright Airship and Contributors */

import Foundation

/// The Config object provides an interface for passing common configurable values to `UAirship`.
/// The simplest way to use this class is to add an AirshipConfig.plist file in your app's bundle and set
/// the desired options.
@objc(UAConfig)
public class AirshipConfig: NSObject, NSCopying {

    /// The development app key. This should match the application on go.urbanairship.com that is
    /// configured with your development push certificate.
    @objc
    public var developmentAppKey: String?

    /// The development app secret. This should match the application on go.urbanairship.com that is
    /// configured with your development push certificate.
    @objc
    public var developmentAppSecret: String?

    /// The production app key. This should match the application on go.urbanairship.com that is
    /// configured with your production push certificate. This is used for App Store, Ad-Hoc and Enterprise
    /// app configurations.
    @objc
    public var productionAppKey: String?

    /// The production app secret. This should match the application on go.urbanairship.com that is
    /// configured with your production push certificate. This is used for App Store, Ad-Hoc and Enterprise
    /// app configurations.
    @objc
    public var productionAppSecret: String?

    /// The log level used for development apps. Defaults to `debug`.
    @objc
    public var developmentLogLevel: AirshipLogLevel = .debug

    /// The log privacy level used for development apps. Allows logging to public console. Defaults to `private`.
    @objc
    public var developmentLogPrivacyLevel: AirshipLogPrivacyLevel = .private

    /// The log level used for production apps. Defaults to `error`.
    @objc
    public var productionLogLevel: AirshipLogLevel = .error

    /// The log privacy level used for production apps. Allows logging to public console. Defaults to `private`.
    @objc
    public var productionLogPrivacyLevel: AirshipLogPrivacyLevel = .private

    /// Auto pause InAppAutomation on launch. Defaults to `false`
    @objc
    public var autoPauseInAppAutomationOnLaunch: Bool = false

    /// Flag to enable or disable web view inspection on Airship created  web views. Applies only to iOS 16.4+.
    /// Defaults to `false`
    @objc
    public var isWebViewInspectionEnabled: Bool = false

    /// The airship cloud site. Defaults to `us`.
    @objc
    public var site: CloudSite = .us

    /// Default enabled Airship features for the app. For more details, see `PrivacyManager`.
    /// Defaults to `all`.
    public var enabledFeatures: AirshipFeature = .all

    /// Allows resetting enabled features to match the runtime config defaults on each takeOff
    /// Defaults to `false`
    @objc
    public var resetEnabledFeatures: Bool = false

    /// :nodoc:
    @objc(enabledFeatures)
    public var _objc_enabledFeatures: _UAFeatures {
        get {
            return enabledFeatures.toObjc
        }
        set {
            enabledFeatures = newValue.toSwift
        }
    }

    /// The default app key. Depending on the `inProduction` status,
    /// `developmentAppKey` or `productionAppKey` will take priority.
    @objc
    public var defaultAppKey: String = ""

    /// The default app secret. Depending on the `inProduction` status,
    /// `developmentAppSecret` or `productionAppSecret` will take priority.
    @objc
    public var defaultAppSecret: String = ""

    /// The production status of this application. This may be set directly, or it may be determined
    /// automatically if the `detectProvisioningMode` flag is set to `true`.
    /// If neither `inProduction` nor `detectProvisioningMode` is set,
    /// `detectProvisioningMode` will be enabled.
    @objc
    public var inProduction: Bool {
        get {
            return detectProvisioningMode
                ? usesProductionPushServer : _inProduction
        }
        set {
            _defaultProvisioningMode = false
            _inProduction = newValue
            _usesProductionPushServer = nil
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
    @objc
    public var detectProvisioningMode: Bool {
        get {
            return _detectProvisioningMode ?? _defaultProvisioningMode
        }
        set {
            _detectProvisioningMode = newValue
        }
    }

    /// NOTE: For internal use only. :nodoc:
    @objc
    public var profilePath: String? {
        didSet {
            _usesProductionPushServer = nil
        }
    }

    private var _usesProductionPushServer: Bool?
    private var usesProductionPushServer: Bool {
        if _usesProductionPushServer == nil {
            if let profilePath = self.profilePath, profilePath.count > 0,
                FileManager.default.fileExists(atPath: profilePath)
            {
                _usesProductionPushServer =
                AirshipConfig.isProductionProvisioningProfile(
                        profilePath
                    )
            } else {
                if self.isSimulator {
                    AirshipLogger.error(
                        "No profile found for the simulator. Defaulting to inProduction flag: \(self._inProduction)"
                    )
                    _usesProductionPushServer = self._inProduction
                } else {
                    AirshipLogger.error(
                        "No profile found, but not a simulator. Defaulting to inProduction = true"
                    )
                    _usesProductionPushServer = true
                }
            }
        }

        return _usesProductionPushServer ?? false
    }

    private var _inProduction = false
    private var _defaultProvisioningMode = true
    private var _detectProvisioningMode: Bool?

    /// If enabled, the Airship library automatically registers for remote notifications when push is enabled
    /// and intercepts incoming notifications in both the foreground and upon launch.
    ///
    /// Defaults to `true`. If this is disabled, you will need to register for remote notifications
    /// in application:didFinishLaunchingWithOptions: and forward all notification-related app delegate
    /// calls to UAPush and UAInbox.
    @objc
    public var isAutomaticSetupEnabled = true

    /// An array of `UAURLAllowList` entry strings.
    /// This url allow list is used for validating which URLs can be opened or load the JavaScript native bridge.
    /// It affects landing pages, the open external URL and wallet actions,
    /// deep link actions (if a delegate is not set), and HTML in-app messages.
    ///
    /// - NOTE: See `UAURLAllowList` for pattern entry syntax.
    @objc(URLAllowList)
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
    @objc(URLAllowListScopeJavaScriptInterface)
    public var urlAllowListScopeJavaScriptInterface: [String] = []

    /// An array of UAURLAllowList entry strings.
    /// This url allow list is used for validating which URLs can be opened.
    /// It affects landing pages, the open external URL and wallet actions,
    /// deep link actions (if a delegate is not set), and HTML in-app messages.
    ///
    /// - NOTE: See `UAURLAllowList` for pattern entry syntax.
    @objc(URLAllowListScopeOpenURL)
    public var urlAllowListScopeOpenURL: [String] = [] {
        didSet {
            isURLAllowListScopeOpenURLSet = true
        }
    }

    var isURLAllowListScopeOpenURLSet: Bool = false


    /// The iTunes ID used for Rate App Actions.
    @objc
    public var itunesID: String?

    /// Toggles Airship analytics. Defaults to `true`. If set to `false`, many Airship features will not be
    /// available to this application.
    @objc
    public var isAnalyticsEnabled = true

    /// The Airship default message center style configuration file.
    @objc
    public var messageCenterStyleConfig: String?

    /// If set to `true`, the Airship user will be cleared if the application is
    /// restored on a different device from an encrypted backup.
    ///
    /// Defaults to `false`.
    @objc
    public var clearUserOnAppRestore = false

    /// If set to `true`, the application will clear the previous named user ID on a
    /// re-install. Defaults to `false`.
    @objc
    public var clearNamedUserOnAppRestore = false

    /// Flag indicating whether channel capture feature is enabled or not.
    ///
    /// Defaults to `true`.
    @objc
    public var isChannelCaptureEnabled = true

    /// Flag indicating whether delayed channel creation is enabled. If set to `true` channel
    /// creation will not occur until channel creation is manually enabled.
    ///
    /// Defaults to `false`.
    @objc
    public var isChannelCreationDelayEnabled = false

    /// Flag indicating whether extended broadcasts are enabled. If set to `true` the AirshipReady NSNotification
    /// will contain additional data: the channel identifier and the app key.
    ///
    /// Defaults to `false`.
    @objc
    public var isExtendedBroadcastsEnabled = false

    /// If set to 'YES', the Airship SDK will request authorization to use
    /// notifications from the user. Apps that set this flag to `false` are
    /// required to request authorization themselves.
    ///
    /// Defaults to `true`.
    @objc
    public var requestAuthorizationToUseNotifications = true

    /// If set to `true`, the SDK will wait for an initial remote config instead of falling back on default API URLs.
    ///
    /// Defaults to `true`.
    @objc
    public var requireInitialRemoteConfigEnabled = true

    /// The Airship URL used to pull the initial config. This should only be set
    /// if you are using custom domains that forward to Airship.
    ///
    @objc
    public var initialConfigURL: String?

    /// The Airship device API url.
    ///
    /// - Note: This option is reserved for internal debugging. :nodoc:
    @objc
    public var deviceAPIURL: String?

    /// The Airship analytics API url.
    ///
    /// - Note: This option is reserved for internal debugging. :nodoc:
    @objc
    public var analyticsURL: String?

    /// The Airship remote data API url.
    ///
    /// - Note: This option is reserved for internal debugging. :nodoc:
    @objc
    public var remoteDataAPIURL: String?

    /// The Airship chat API URL.
    @objc
    public var chatURL: String?

    /// The Airship web socket URL.
    @objc
    public var chatWebSocketURL: String?

    /// If set to `true`, the SDK will use the preferred locale. Otherwise it will use the current locale.
    ///
    /// Defaults to `false`.
    @objc
    public var useUserPreferredLocale = false

    /// If set to `true`, Message Center will attempt to be restored between reinstalls. If `false`,
    /// the Message Center user will be reset and the Channel will not be able to use the user
    /// as an identity hint to recover the past Channel ID.
    ///
    /// Defaults to `true`.
    @objc
    public var restoreMessageCenterOnReinstall = true

    /// Returns the resolved app key.
    /// - Returns: The resolved app key or an empty string.
    @objc
    public var appKey: String {
        let key = inProduction ? productionAppKey : developmentAppKey
        return key ?? defaultAppKey
    }

    /// Returns the resolved app secret.
    /// - Returns: The resolved app key or an empty string.
    @objc
    public var appSecret: String {
        let secret = inProduction ? productionAppSecret : developmentAppSecret
        return secret ?? defaultAppSecret
    }

    /// Returns the resolved log level.
    /// - Returns: The resolved log level.
    @objc
    public var logLevel: AirshipLogLevel {
        return inProduction ? productionLogLevel : developmentLogLevel
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

    /// Creates an instance using the values set in the `AirshipConfig.plist` file.
    /// - Returns: A config with values from `AirshipConfig.plist` file.
    @objc(defaultConfig)
    public class func `default`() -> AirshipConfig {
        return AirshipConfig(
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
    @objc
    public class func config(contentsOfFile path: String?) -> AirshipConfig {
        return AirshipConfig(contentsOfFile: path)
    }

    /// Creates an instance with empty values.
    /// - Returns: A config with empty values.
    @objc
    public class func config() -> AirshipConfig {
        return AirshipConfig()
    }

    /**
     * Creates an instance using the values found in the specified `.plist` file.
     * - Parameter path: The path of the specified file.
     * - Returns: A config with values from the specified file.
     */
    @objc
    public convenience init(contentsOfFile path: String?) {
        self.init()
        if let path = path {
            //copy from dictionary plist
            if let configDict = NSDictionary(contentsOfFile: path)
                as? [AnyHashable: Any]
            {
                self.applyConfig(configDict)
            }
        }
    }

    /// Creates an instance with empty values.
    /// - Returns: A Config with empty values.
    @objc
    public override init() {
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
    }

    public func copy(with zone: NSZone? = nil) -> Any {
        return AirshipConfig(self)
    }

    public override var description: String {
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
    @objc
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

    private func applyConfig(_ keyedValues: [AnyHashable: Any]) {
        let oldKeyMap = [
            "LOG_LEVEL": "developmentLogLevel",
            "PRODUCTION_APP_KEY": "productionAppKey",
            "PRODUCTION_APP_SECRET": "productionAppSecret",
            "DEVELOPMENT_APP_KEY": "developmentAppKey",
            "DEVELOPMENT_APP_SECRET": "developmentAppSecret",
            "APP_STORE_OR_AD_HOC_BUILD": "inProduction",
            "AIRSHIP_SERVER": "deviceAPIURL",
            "ANALYTICS_SERVER": "analyticsURL",
            "whitelist": "urlAllowList",
            "analyticsEnabled": "isAnalyticsEnabled",
            "extendedBroadcastsEnabled": "isExtendedBroadcastsEnabled",
            "channelCaptureEnabled": "isChannelCaptureEnabled",
            "channelCreationDelayEnabled": "isChannelCreationDelayEnabled",
            "automaticSetupEnabled": "isAutomaticSetupEnabled",
            "isInProduction": "inProduction",
        ]

        let swiftToObjcMap = [
            "urlAllowList": "URLAllowList",
            "urlAllowListScopeOpenURL": "URLAllowListScopeOpenURL",
            "urlAllowListScopeJavaScriptInterface":
                "URLAllowListScopeJavaScriptInterface",
        ]

        let mirror = Mirror(reflecting: self)
        var propertyInfo: [String: (String, Any.Type)] = [:]
        mirror.children.forEach { child in
            if let label = child.label {
                var normalizedLabel = label
                if normalizedLabel.hasPrefix("_") {
                    normalizedLabel.removeFirst()
                }

                if let objcName = swiftToObjcMap[normalizedLabel] {
                    normalizedLabel = objcName
                }

                propertyInfo[normalizedLabel.lowercased()] = (
                    normalizedLabel, type(of: child.value)
                )
            }
        }

        for key in keyedValues.keys {
            guard var key = (key as? String) else {
                continue
            }

            guard var value = keyedValues[key] else {
                continue
            }

            if let newKey = oldKeyMap[key] {
                AirshipLogger.warn(
                    "\(key) is a legacy config key, use \(newKey) instead"
                )
                key = newKey
            }

            // Trim any strings
            if let stringValue = value as? String {
                value = stringValue.trimmingCharacters(
                    in: CharacterSet.whitespaces
                )
            }

            if let propertyInfo = propertyInfo[key.lowercased()] {
                let propertyKey = propertyInfo.0
                let propertyType = propertyInfo.1

                var normalizedValue: Any?
                if propertyType == CloudSite.self
                    || propertyType == CloudSite?.self
                {
                    // we do all the work to parse it to a log level, but setValue(forKey:) does not work for enums
                    normalizedValue = AirshipConfig.coerceSite(value)?.rawValue
                } else if propertyType == AirshipLogLevel.self
                    || propertyType == AirshipLogLevel?.self
                {
                    // we do all the work to parse it to a log level, but setValue(forKey:) does not work for enums
                    normalizedValue = AirshipConfig.coerceLogLevel(value)?.rawValue
                } else if propertyType == AirshipLogPrivacyLevel.self
                        || propertyType == AirshipLogPrivacyLevel?.self
                {
                    normalizedValue = AirshipConfig.coerceLogPrivacyLevel(value)?.rawValue
                } else if propertyType == AirshipFeature.self
                    || propertyType == AirshipFeature?.self
                {
                    normalizedValue = AirshipConfig.coerceFeatures(value)?.rawValue
                } else if propertyType == String.self
                    || propertyType == String?.self
                {
                    normalizedValue = AirshipConfig.coerceString(value)
                } else if propertyType == Bool.self
                    || propertyType == Bool?.self
                {
                    normalizedValue = AirshipConfig.coerceBool(value)
                } else {
                    normalizedValue = value
                }

                if let normalizedValue = normalizedValue {
                    self.setValue(normalizedValue, forKey: propertyKey)
                } else {
                    AirshipLogger.error(
                        "Invalid config \(propertyKey)(\(key)) \(value)"
                    )
                }
            } else {
                AirshipLogger.error("Unknown config \(key)")
            }


        }
    }

    private class func coerceString(_ value: Any) -> String? {
        if let value = value as? String {
            return value
        }

        if let value = value as? Character {
            return String(value)
        }

        return nil
    }

    private class func coerceBool(_ value: Any) -> Bool? {
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

    private class func coerceSite(_ value: Any) -> CloudSite? {
        if let site = value as? CloudSite {
            return site
        }

        if let rawValue = value as? Int {
            return CloudSite(rawValue: rawValue)
        }

        if let rawValue = value as? UInt {
            return CloudSite(rawValue: Int(rawValue))
        }

        if let number = value as? NSNumber {
            return CloudSite(rawValue: number.intValue)
        }

        if let string = value as? String {
            return CloudSiteNames(rawValue: string.lowercased())?.toSite()
        }

        return nil
    }

    private class func coerceLogLevel(_ value: Any) -> AirshipLogLevel? {
        if let logLevel = value as? AirshipLogLevel {
            return logLevel
        }

        if let rawValue = value as? Int {
            return AirshipLogLevel(rawValue: rawValue)
        }

        if let rawValue = value as? UInt {
            return AirshipLogLevel(rawValue: Int(rawValue))
        }

        if let number = value as? NSNumber {
            return AirshipLogLevel(rawValue: number.intValue)
        }

        if let string = value as? String {
            guard let int = Int(string) else {
                return LogLevelNames(
                    rawValue: string.lowercased()
                )?.toLogLevel()
            }
            return AirshipLogLevel(rawValue: int)
        }

        return nil
    }

    private class func coerceLogPrivacyLevel(_ value: Any) -> AirshipLogPrivacyLevel? {
        if let logPrivacyLevel = value as? AirshipLogPrivacyLevel {
            return logPrivacyLevel
        }

        if let rawValue = value as? Int {
            return AirshipLogPrivacyLevel(rawValue: rawValue)
        }

        if let rawValue = value as? UInt {
            return AirshipLogPrivacyLevel(rawValue: Int(rawValue))
        }

        if let number = value as? NSNumber {
            return AirshipLogPrivacyLevel(rawValue: number.intValue)
        }

        if let string = value as? String {
            guard let int = Int(string) else {
                return LogPrivacyLevelNames(
                    rawValue: string.lowercased()
                )?.toLogPrivacyLevel()
            }
            return AirshipLogPrivacyLevel(rawValue: int)
        }

        return nil
    }

    private class func coerceFeatures(_ value: Any) -> AirshipFeature? {
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
    @objc
    public class func isProductionProvisioningProfile(_ profilePath: String)
        -> Bool
    {
        AirshipLogger.trace("Profile path: \(profilePath)")

        // Attempt to read this file as ASCII (rather than UTF-8) due to the binary blocks before and after the plist data
        guard
            let embeddedProfile: String = try? String(
                contentsOfFile: profilePath,
                encoding: .ascii
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

    public override func setValue(_ value: Any?, forUndefinedKey key: String) {
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
}

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
