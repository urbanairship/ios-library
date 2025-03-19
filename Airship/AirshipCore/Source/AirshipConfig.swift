/* Copyright Airship and Contributors */

import Foundation

/// The Config object provides an interface for passing common configurable values to `Airship`.
public struct AirshipConfig: Decodable, Sendable {

    /// The default app key. Used as the default value for `developmentAppKey` or `productionAppKey`.
    public var defaultAppKey: String?

    /// The default app secret. Used as the default value for `developmentAppSecret` or `productionAppSecret`.
    public var defaultAppSecret: String?

    /// The  app key used when `inProduction` is `false`.
    ///
    /// The development credentails are generally used to point to a Test Airship project which will send to
    /// the development  APNS sandbox.
    public var developmentAppKey: String?

    /// The  app secret used when `inProduction` is `false`.
    public var developmentAppSecret: String?

    /// The log level used when `inProduction` is `false`.
    public var developmentLogLevel: AirshipLogLevel = .debug

    /// The log privacy level used when `inProduction` is `false`.  Allows logging to public console.
    /// Defaults to `private`.
    public var developmentLogPrivacyLevel: AirshipLogPrivacyLevel = .private

    /// The  app key used when `inProduction` is `true`.
    ///
    /// The production credentails are generally used to point to a Live Airship project which will send to
    /// the production  APNS sandbox.
    public var productionAppKey: String?

    /// The  app secret used when `inProduction` is `true`.
    public var productionAppSecret: String?

    /// The log privacy level used when `inProduction` is `true`.  Allows logging to public console.
    /// Defaults to `error`.
    public var productionLogLevel: AirshipLogLevel = .error

    /// The log privacy level used when `inProduction` is `true`.  Allows logging to public console.
    /// Only used by the default log handler.
    /// Defaults to `private`.
    public var productionLogPrivacyLevel: AirshipLogPrivacyLevel = .private

    /// Custom log handler to be used instead of the default Airship log handler.
    public var logHandler: (any AirshipLogHandler)? = nil

    /// Auto pause InAppAutomation on launch. Defaults to `false`
    public var autoPauseInAppAutomationOnLaunch: Bool = false
    
    /// Flag to enable or disable web view inspection on Airship created  web views. Applies only to iOS 16.4+.
    /// Defaults to `false`
    public var isWebViewInspectionEnabled: Bool = false

    // Overrides the input validation used by Preference Center and Scenes.
    public var inputValidationOverrides: AirshipInputValidation.OverridesClosure?

    /// Optional closure for auth challenge certificate validation.
    public var connectionChallengeResolver: ChallengeResolveClosure?
    
    /// A closure that can be used to manually recover the channel ID instead of having
    /// Airship recover or generate an ID automatically.
    ///
    /// This is a delicate API that should only be used if the application can ensure the channel ID was previously created and by recovering
    /// it will only be used by a single device. Having multiple devices with the same channel ID will cause unpredictable behavior.
    ///
    /// When the method is set to `restore`, the user must provide a previously generated, unique
    /// If the closure throws an error, Airship will delay channel registration until a successful execution.
    public var restoreChannelID: AirshipChannelCreateOptionClosure?

    /// The airship cloud site. Defaults to `us`.
    public var site: CloudSite = .us
   
    /// Default enabled Airship features for the app. For more details, see `PrivacyManager`.
    /// Defaults to `all`.
    public var enabledFeatures: AirshipFeature = .all

    /// Allows resetting enabled features to match the runtime config defaults on each takeOff
    /// Defaults to `false`
    public var resetEnabledFeatures: Bool = false

    /// Used to select between the either production (`true`) or development (`false`) credentails
    /// and logging.
    ///
    /// If not set, Airship will pick the credentials based on the APNS sandbox by inspecting the profile on the
    /// device. If Airship fails to resolve the APNS environment `inProduction` will default to `true`.
    public var inProduction: Bool?

    /// If enabled, the Airship library automatically registers for remote notifications when push is enabled
    /// and intercepts incoming notifications in both the foreground and upon launch.
    ///
    /// If disabled, the app needs to forward methods to Airship. See https://docs.airship.com/platform/mobile/setup/sdk/ios/#automatic-integration
    /// for more details.
    ///
    /// Defaults to `true`.
    public var isAutomaticSetupEnabled: Bool = true

    /// An array of `UAURLAllowList` entry strings.
    /// This url allow list is used for validating which URLs can be opened or load the JavaScript native bridge.
    /// It affects landing pages, the open external URL and wallet actions,
    /// deep link actions (if a delegate is not set), and HTML in-app messages.
    ///
    /// - NOTE: See `UAURLAllowList` for pattern entry syntax.
    public var urlAllowList: [String]? = nil

    /// An array of` UAURLAllowList` entry strings.
    /// This url allow list is used for validating which URLs can load the JavaScript native bridge,
    /// It affects Landing Pages, Message Center and HTML In-App Messages.
    ///
    /// - NOTE: See `UAURLAllowList` for pattern entry syntax.
    public var urlAllowListScopeJavaScriptInterface: [String]? = nil

    /// An array of UAURLAllowList entry strings.
    /// This url allow list is used for validating which URLs can be opened.
    /// It affects landing pages, the open external URL and wallet actions,
    /// deep link actions (if a delegate is not set), and HTML in-app messages.
    ///
    /// - NOTE: See `UAURLAllowList` for pattern entry syntax.
    public var urlAllowListScopeOpenURL: [String]? = nil

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

    /// If set to `true`, the Airship SDK will request authorization to use
    /// notifications from the user. Apps that set this flag to `false` are
    /// required to request authorization themselves.
    ///
    /// Defaults to `true`.
    public var requestAuthorizationToUseNotifications: Bool = true

    /// If set to `true`, the SDK will wait for an initial remote config instead of falling back on default API URLs.
    ///
    /// Defaults to `true`.
    public var requireInitialRemoteConfigEnabled: Bool = true
    
    /// The Airship URL used to pull the initial config. This should only be set if you are using custom domains
    /// that forward to Airship.
    public var initialConfigURL: String?

    /// If set to `true`, the SDK will use the preferred locale. Otherwise it will use the current locale.
    ///
    /// Defaults to `false`.
    public var useUserPreferredLocale: Bool = false

    /// If set to `true`, Message Center will attempt to be restored between reinstalls. If `false`,
    /// the Message Center user will be reset and the Channel will not be able to use the user
    /// as an identity hint to recover the past Channel ID.
    ///
    /// Defaults to `true`.
    public var restoreMessageCenterOnReinstall: Bool = true

    enum CodingKeys: String, CodingKey {
        case defaultAppKey
        case defaultAppSecret
        case developmentAppKey
        case developmentAppSecret
        case productionAppKey
        case productionAppSecret
        case developmentLogLevel
        case developmentLogPrivacyLevel
        case productionLogLevel
        case productionLogPrivacyLevel
        case resetEnabledFeatures
        case enabledFeatures
        case site
        case messageCenterStyleConfig
        case isExtendedBroadcastsEnabled
        case isChannelCreationDelayEnabled
        case requireInitialRemoteConfigEnabled
        case urlAllowListScopeOpenURL
        case inProduction
        case autoPauseInAppAutomationOnLaunch
        case isWebViewInspectionEnabled
        case isAutomaticSetupEnabled
        case urlAllowList
        case urlAllowListScopeJavaScriptInterface
        case itunesID
        case isAnalyticsEnabled
        case clearUserOnAppRestore
        case clearNamedUserOnAppRestore
        case isChannelCaptureEnabled
        case requestAuthorizationToUseNotifications
        case initialConfigURL
        case deviceAPIURL
        case analyticsURL
        case remoteDataAPIURL
        case useUserPreferredLocale
        case restoreMessageCenterOnReinstall
        
        // legacy keys
        
        case LOG_LEVEL
        case PRODUCTION_APP_KEY
        case PRODUCTION_APP_SECRET
        case DEVELOPMENT_APP_KEY
        case DEVELOPMENT_APP_SECRET
        case APP_STORE_OR_AD_HOC_BUILD
        case isInProduction
        case whitelist
        case analyticsEnabled
        case extendedBroadcastsEnabled
        case channelCaptureEnabled
        case channelCreationDelayEnabled
        case automaticSetupEnabled
    }

    /// Creates an instance with empty values.
    /// - Returns: A config with empty values.
    public init() {
    }

    /// Creates an instance using the values set in the `AirshipConfig.plist` file.
    /// - Returns: A config with values from `AirshipConfig.plist` file.
    public static func `default`() throws -> AirshipConfig {
        guard
            let path = Bundle.main.path(
                forResource: "AirshipConfig",
                ofType: "plist"
            )
        else {
            throw AirshipErrors.error("AirshipConfig.plist file is missing.")
        }

        return try AirshipConfig(fromPlist: path)
    }

    /**
     * Creates an instance using the values found in the specified `.plist` file.
     * - Parameter fromPlist: The path of the specified plist file.
     * - Returns: A config with values from the specified file.
     */
    public init(fromPlist path: String) throws {
        guard let data = FileManager.default.contents(atPath: path) else {
            throw AirshipErrors.error("Failed to load contents of the plist file \(path)")
        }

        let decoder = PropertyListDecoder()
        self = try decoder.decode(AirshipConfig.self, from: data)
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Development
        self.developmentAppKey = try container.decodeFirst(
            String.self,
            forKeys: [.developmentAppKey, .DEVELOPMENT_APP_KEY]
        )

        self.developmentAppSecret = try container.decodeFirst(
            String.self,
            forKeys: [.developmentAppSecret, .DEVELOPMENT_APP_SECRET]
        )

        self.developmentLogLevel = try container.decodeFirst(
            AirshipLogLevel.self,
            forKeys: [.developmentLogLevel, .LOG_LEVEL]
        ) ?? self.developmentLogLevel

        self.developmentLogPrivacyLevel = try container.decodeIfPresent(
            AirshipLogPrivacyLevel.self,
            forKey: .developmentLogPrivacyLevel
        ) ?? self.developmentLogPrivacyLevel


        // Production
        self.productionAppKey = try container.decodeFirst(
            String.self,
            forKeys: [.productionAppKey, .PRODUCTION_APP_KEY]
        )

        self.productionAppSecret = try container.decodeFirst(
            String.self,
            forKeys: [.productionAppSecret, .PRODUCTION_APP_SECRET]
        )

        self.productionLogLevel = try container.decodeIfPresent(
            AirshipLogLevel.self,
            forKey: .productionLogLevel
        ) ?? self.productionLogLevel

        self.productionLogPrivacyLevel = try container.decodeIfPresent(
            AirshipLogPrivacyLevel.self,
            forKey: .productionLogPrivacyLevel
        ) ?? self.productionLogPrivacyLevel


        // In production
        self.inProduction = try container.decodeFirst(
            Bool.self,
            forKeys: [.inProduction, .isInProduction, .APP_STORE_OR_AD_HOC_BUILD]
        )

        // Site
        self.site = try container.decodeIfPresent(
            CloudSite.self,
            forKey: .site
        ) ?? self.site

        // Default credentials
        self.defaultAppKey = try container.decodeIfPresent(
            String.self,
            forKey: .defaultAppKey
        )
        self.defaultAppSecret = try container.decodeIfPresent(
            String.self,
            forKey: .defaultAppSecret
        )

        // Allow lists
        self.urlAllowList = try container.decodeFirst(
            [String].self,
            forKeys: [.urlAllowList, .whitelist]
        )

        self.urlAllowListScopeOpenURL = try container.decodeIfPresent(
            [String].self,
            forKey: .urlAllowListScopeOpenURL
        )

        self.urlAllowListScopeJavaScriptInterface = try container.decodeIfPresent(
            [String].self,
            forKey: .urlAllowListScopeJavaScriptInterface
        )

        // Features
        self.resetEnabledFeatures = try container.decodeIfPresent(
            Bool.self,
            forKey: .resetEnabledFeatures
        ) ?? self.resetEnabledFeatures

        self.enabledFeatures = try container.decodeIfPresent(
            AirshipFeature.self,
            forKey: .enabledFeatures
        ) ?? self.enabledFeatures

        self.isAnalyticsEnabled = try container.decodeFirst(
            Bool.self,
            forKeys: [.isAnalyticsEnabled, .analyticsEnabled]
        ) ?? self.isAnalyticsEnabled


        // Message Center
        self.messageCenterStyleConfig = try container.decodeIfPresent(
            String.self,
            forKey: .messageCenterStyleConfig
        )

        self.restoreMessageCenterOnReinstall = try container.decodeIfPresent(
            Bool.self,
            forKey: .restoreMessageCenterOnReinstall
        ) ?? self.restoreMessageCenterOnReinstall


        // Core
        self.initialConfigURL = try container.decodeIfPresent(
            String.self,
            forKey: .initialConfigURL
        )

        self.itunesID = try container.decodeIfPresent(
            String.self,
            forKey: .itunesID
        )

        self.isExtendedBroadcastsEnabled = try container.decodeFirst(
            Bool.self,
            forKeys: [.isExtendedBroadcastsEnabled, .extendedBroadcastsEnabled]
        ) ?? self.isExtendedBroadcastsEnabled

        self.isChannelCreationDelayEnabled = try container.decodeFirst(
            Bool.self,
            forKeys: [.isChannelCreationDelayEnabled, .channelCreationDelayEnabled]
        ) ?? self.isChannelCreationDelayEnabled

        self.requireInitialRemoteConfigEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .requireInitialRemoteConfigEnabled
        ) ?? self.requireInitialRemoteConfigEnabled

        self.autoPauseInAppAutomationOnLaunch = try container.decodeIfPresent(
            Bool.self,
            forKey: .autoPauseInAppAutomationOnLaunch
        ) ?? self.autoPauseInAppAutomationOnLaunch

        self.isWebViewInspectionEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .isWebViewInspectionEnabled
        ) ?? self.isWebViewInspectionEnabled

        self.isAutomaticSetupEnabled = try container.decodeFirst(
            Bool.self,
            forKeys: [.isAutomaticSetupEnabled, .automaticSetupEnabled]
        ) ?? self.isAutomaticSetupEnabled

        self.clearUserOnAppRestore = try container.decodeIfPresent(
            Bool.self,
            forKey: .clearUserOnAppRestore
        ) ?? false

        self.clearNamedUserOnAppRestore = try container.decodeIfPresent(
            Bool.self,
            forKey: .clearNamedUserOnAppRestore
        ) ?? self.clearNamedUserOnAppRestore

        self.isChannelCaptureEnabled = try container.decodeFirst(
            Bool.self,
            forKeys: [.isChannelCaptureEnabled, .channelCaptureEnabled]
        ) ?? self.isChannelCaptureEnabled

        self.requestAuthorizationToUseNotifications = try container.decodeIfPresent(
            Bool.self,
            forKey: .requestAuthorizationToUseNotifications
        ) ?? self.requestAuthorizationToUseNotifications

        self.useUserPreferredLocale = try container.decodeIfPresent(
            Bool.self,
            forKey: .useUserPreferredLocale
        ) ?? self.useUserPreferredLocale
    }

    /// Validates credentails
    /// - Parameters:
    ///     - inProduction: To validate production or development credentials
    public func validateCredentials(inProduction: Bool) throws {
        _ = try self.resolveCredentails(inProduction)
    }

    func logIssues() {
        if (inProduction == nil) {
            do {
                try validateCredentials(inProduction: true)
            } catch {
                AirshipLogger.warn("Airship will automatically pick between production and development credentials, but production credentials are invalid \(error)")
            }

            do {
                try validateCredentials(inProduction: false)
            } catch {
                AirshipLogger.warn("Airship will automatically pick between production and development credentials, but development credentials are invalid \(error)")
            }

            if productionAppKey == developmentAppKey {
                AirshipLogger.warn("Production & Developemtn app keys match")
            }

            if productionAppSecret == developmentAppSecret {
                AirshipLogger.warn("Production & Developemtn app secrets match")
            }
        }

        if (urlAllowList == nil && urlAllowListScopeOpenURL == nil) {
            AirshipLogger.impError(
                "The Airship config options is missing URL allow list rules for SCOPE_OPEN " +
                "that controls what external URLs are able to be opened externally or loaded " +
                "in a web view by Airship. By default, all URLs will be allowed. " +
                "To suppress this error, specify the config urlAllowListScopeOpenURL = [*] " +
                "to keep the defaults, or by providing a list of rules that your app expects. " +
                "See https://docs.airship.com/platform/mobile/setup/sdk/ios/#url-allow-list " +
                "for more information."
            )
        }
    }
}

public extension AirshipConfig {
    /// Resolves the inProduction flag. The value will be resolved with:
    /// - `inProduction` if set
    /// - `false` if the target environment is a simulator
    /// - by inspecting the `embedded.mobileprovision` file to look up the APNS environment.
    ///
    /// - returns  The resolved in production flag.
    /// - throws If the APNS fails to resolve to an environment. Airship will fallback to assuming its inProduction during
    /// takeOff.
    func resolveInProduction() throws -> Bool {
        if let inProduction {
            return inProduction
        }

#if targetEnvironment(simulator)
        return false
#else
        return try APNSEnvironment.isProduction()
#endif
    }
}

// The Channel generation method. In `automatic` mode Airship will generate a new channelID and create a new channel.
// If the restore option is specified and `channelID` is a correct ID, Airship will try to restore a channel with the specified ID
public enum ChannelGenerationMethod {
    case automatic
    case restore(channelID: String)
}

public typealias AirshipChannelCreateOptionClosure = (@Sendable () async throws -> ChannelGenerationMethod)

extension AirshipConfig {
    func resolveCredentails(_ inProduction: Bool) throws -> AirshipAppCredentials {
        let appKey = (inProduction ? productionAppKey : developmentAppKey) ?? defaultAppKey
        let appSecret = (inProduction ? productionAppSecret : developmentAppSecret) ?? defaultAppSecret

        let matchPred = NSPredicate(format: "SELF MATCHES %@", "^\\S{22}+$")

        guard
            let appKey,
            matchPred.evaluate(with: appKey),
            let appSecret,
            matchPred.evaluate(with: appSecret),
            appKey != appSecret
        else {
            throw AirshipErrors.error(
                "Invalid app credentials \(appKey ?? ""):\(appSecret ?? "")"
            )
        }

        return AirshipAppCredentials(
            appKey: appKey,
            appSecret: appSecret
        )
    }
}

fileprivate extension KeyedDecodingContainerProtocol {
    func decodeFirst<T: Decodable>(_ type: T.Type, forKeys: [Self.Key]) throws -> T? where T : Decodable {
        for (_, key) in forKeys.enumerated() {
            if let value = try self.decodeIfPresent(type, forKey: key) {
                return value
            }
        }
        return nil
    }
}
