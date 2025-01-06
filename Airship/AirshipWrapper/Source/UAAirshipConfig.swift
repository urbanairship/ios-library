/* Copyright Airship and Contributors */

import Foundation
public import AirshipCore

/// The Config object provides an interface for passing common configurable values to `UAirship`.
/// The simplest way to use this class is to add an AirshipConfig.plist file in your app's bundle and set
/// the desired options.
@objc(UAConfig)
public class UAAirshipConfig: NSObject {
   
    var config: AirshipConfig
    
    /// The development app key. This should match the application on go.urbanairship.com that is
    /// configured with your development push certificate.
    @objc
    public var developmentAppKey: String? {
        get {
            return config.developmentAppKey
        }
        set {
            config.developmentAppKey = newValue
        }
    }
    
    /// The development app secret. This should match the application on go.urbanairship.com that is
    /// configured with your development push certificate.
    @objc
    public var developmentAppSecret: String? {
        get {
            return config.developmentAppSecret
        }
        set {
            config.developmentAppSecret = newValue
        }
    }

    /// The production app key. This should match the application on go.urbanairship.com that is
    /// configured with your production push certificate. This is used for App Store, Ad-Hoc and Enterprise
    /// app configurations.
    @objc
    public var productionAppKey: String? {
        get {
            return config.productionAppKey
        }
        set {
            config.productionAppKey = newValue
        }
    }

    /// The production app secret. This should match the application on go.urbanairship.com that is
    /// configured with your production push certificate. This is used for App Store, Ad-Hoc and Enterprise
    /// app configurations.
    @objc
    public var productionAppSecret: String? {
        get {
            return config.productionAppSecret
        }
        set {
            config.productionAppSecret = newValue
        }
    }

    /// The log level used for development apps. Defaults to `debug`.
    @objc
    public var developmentLogLevel: UAAirshipLogLevel {
        get {
            return UAHelpers.toLogLevel(level: config.developmentLogLevel)
        }
        set {
            config.developmentLogLevel = UAHelpers.toAirshipLogLevel(level: newValue)
        }
    }

    /// The log level used for production apps. Defaults to `error`.
    @objc
    public var productionLogLevel: UAAirshipLogLevel {
        get {
            return UAHelpers.toLogLevel(level: config.productionLogLevel)
        }
        set {
            config.productionLogLevel = UAHelpers.toAirshipLogLevel(level: newValue)
        }
    }

    /// Auto pause InAppAutomation on launch. Defaults to `false`
    @objc
    public var autoPauseInAppAutomationOnLaunch: Bool {
        get {
            return config.autoPauseInAppAutomationOnLaunch
        }
        set {
            config.autoPauseInAppAutomationOnLaunch = newValue
        }
    }

    /// The airship cloud site. Defaults to `us`.
    @objc
    public var site: UACloudSite {
        get {
            return UAHelpers.toSite(site: config.site)
        }
        set {
            config.site = UAHelpers.toAirshipSite(site: newValue)
        }
    }

    @objc(enabledFeatures)
    public var enabledFeatures: UAFeature {
        get {
            return config.enabledFeatures.asUAFeature
        }
        set {
            config.enabledFeatures = newValue.asAirshipFeature
        }
    }

    /// The default app key. Depending on the `inProduction` status,
    /// `developmentAppKey` or `productionAppKey` will take priority.
    @objc
    public var defaultAppKey: String? {
        get {
            return config.defaultAppKey
        }
        set {
            config.defaultAppKey = newValue
        }
    }

    /// The default app secret. Depending on the `inProduction` status,
    /// `developmentAppSecret` or `productionAppSecret` will take priority.
    @objc
    public var defaultAppSecret: String? {
        get {
            return config.defaultAppSecret
        }
        set {
            config.defaultAppSecret = newValue
        }
    }

    /// The production status of this application. This may be set directly, or it may be determined
    /// automatically if the `detectProvisioningMode` flag is set to `true`.
    /// If neither `inProduction` nor `detectProvisioningMode` is set,
    /// `detectProvisioningMode` will be enabled.
    @objc
    public var inProduction: NSNumber? {
        get {
            return if let inProduction = config.inProduction {
                NSNumber(value: inProduction)
            } else {
                nil
            }
        }
        set {
            config.inProduction = newValue?.boolValue
        }
    }

    /// If enabled, the Airship library automatically registers for remote notifications when push is enabled
    /// and intercepts incoming notifications in both the foreground and upon launch.
    ///
    /// Defaults to `true`. If this is disabled, you will need to register for remote notifications
    /// in application:didFinishLaunchingWithOptions: and forward all notification-related app delegate
    /// calls to UAPush and UAInbox.
    @objc
    public var isAutomaticSetupEnabled: Bool  {
        get {
            return config.isAutomaticSetupEnabled
        }
        set {
            config.isAutomaticSetupEnabled = newValue
        }
    }

    /// An array of `UAURLAllowList` entry strings.
    /// This url allow list is used for validating which URLs can be opened or load the JavaScript native bridge.
    /// It affects landing pages, the open external URL and wallet actions,
    /// deep link actions (if a delegate is not set), and HTML in-app messages.
    ///
    /// - NOTE: See `UAURLAllowList` for pattern entry syntax.
    @objc(URLAllowList)
    public var urlAllowList: [String]? {
        get {
            return config.urlAllowList
        }
        set {
            config.urlAllowList = newValue
        }
    }

    /// An array of` UAURLAllowList` entry strings.
    /// This url allow list is used for validating which URLs can load the JavaScript native bridge,
    /// It affects Landing Pages, Message Center and HTML In-App Messages.
    ///
    /// - NOTE: See `UAURLAllowList` for pattern entry syntax.
    @objc(URLAllowListScopeJavaScriptInterface)
    public var urlAllowListScopeJavaScriptInterface: [String]? {
        get {
            return config.urlAllowListScopeJavaScriptInterface
        }
        set {
            config.urlAllowListScopeJavaScriptInterface = newValue
        }
    }

    /// An array of UAURLAllowList entry strings.
    /// This url allow list is used for validating which URLs can be opened.
    /// It affects landing pages, the open external URL and wallet actions,
    /// deep link actions (if a delegate is not set), and HTML in-app messages.
    ///
    /// - NOTE: See `UAURLAllowList` for pattern entry syntax.
    @objc(URLAllowListScopeOpenURL)
    public var urlAllowListScopeOpenURL: [String]? {
        get {
            return config.urlAllowListScopeOpenURL
        }
        set {
            config.urlAllowListScopeOpenURL = newValue
        }
    }

    /// The iTunes ID used for Rate App Actions.
    @objc
    public var itunesID: String? {
        get {
            return config.itunesID
        }
        set {
            config.itunesID = newValue
        }
    }

    /// Toggles Airship analytics. Defaults to `true`. If set to `false`, many Airship features will not be
    /// available to this application.
    @objc
    public var isAnalyticsEnabled: Bool {
        get {
            return config.isAnalyticsEnabled
        }
        set {
            config.isAnalyticsEnabled = newValue
        }
    }

    /// The Airship default message center style configuration file.
    @objc
    public var messageCenterStyleConfig: String? {
        get {
            return config.messageCenterStyleConfig
        }
        set {
            config.messageCenterStyleConfig = newValue
        }
    }

    /// If set to `true`, the Airship user will be cleared if the application is
    /// restored on a different device from an encrypted backup.
    ///
    /// Defaults to `false`.
    @objc
    public var clearUserOnAppRestore: Bool {
        get {
            return config.clearUserOnAppRestore
        }
        set {
            config.clearUserOnAppRestore = newValue
        }
    }

    /// If set to `true`, the application will clear the previous named user ID on a
    /// re-install. Defaults to `false`.
    @objc
    public var clearNamedUserOnAppRestore: Bool {
        get {
            return config.clearNamedUserOnAppRestore
        }
        set {
            config.clearNamedUserOnAppRestore = newValue
        }
    }

    /// Flag indicating whether channel capture feature is enabled or not.
    ///
    /// Defaults to `true`.
    @objc
    public var isChannelCaptureEnabled: Bool {
        get {
            return config.isChannelCaptureEnabled
        }
        set {
            config.isChannelCaptureEnabled = newValue
        }
    }

    /// Flag indicating whether delayed channel creation is enabled. If set to `true` channel
    /// creation will not occur until channel creation is manually enabled.
    ///
    /// Defaults to `false`.
    @objc
    public var isChannelCreationDelayEnabled: Bool {
        get {
            return config.isChannelCreationDelayEnabled
        }
        set {
            config.isChannelCreationDelayEnabled = newValue
        }
    }

    /// Flag indicating whether extended broadcasts are enabled. If set to `true` the AirshipReady NSNotification
    /// will contain additional data: the channel identifier and the app key.
    ///
    /// Defaults to `false`.
    @objc
    public var isExtendedBroadcastsEnabled: Bool {
        get {
            return config.isExtendedBroadcastsEnabled
        }
        set {
            config.isExtendedBroadcastsEnabled = newValue
        }
    }

    /// If set to 'YES', the Airship SDK will request authorization to use
    /// notifications from the user. Apps that set this flag to `false` are
    /// required to request authorization themselves.
    ///
    /// Defaults to `true`.
    @objc
    public var requestAuthorizationToUseNotifications: Bool {
        get {
            return config.requestAuthorizationToUseNotifications
        }
        set {
            config.requestAuthorizationToUseNotifications = newValue
        }
    }

    /// If set to `true`, the SDK will wait for an initial remote config instead of falling back on default API URLs.
    ///
    /// Defaults to `true`.
    @objc
    public var requireInitialRemoteConfigEnabled: Bool {
        get {
            return config.requireInitialRemoteConfigEnabled
        }
        set {
            config.requireInitialRemoteConfigEnabled = newValue
        }
    }

    /// The Airship URL used to pull the initial config. This should only be set
    /// if you are using custom domains that forward to Airship.
    ///
    @objc
    public var initialConfigURL: String? {
        get {
            return config.initialConfigURL
        }
        set {
            config.initialConfigURL = newValue
        }
    }

    /// If set to `true`, the SDK will use the preferred locale. Otherwise it will use the current locale.
    ///
    /// Defaults to `false`.
    @objc
    public var useUserPreferredLocale: Bool {
        get {
            return config.useUserPreferredLocale
        }
        set {
            config.useUserPreferredLocale = newValue
        }
    }

    /// Creates an instance using the values set in the `AirshipConfig.plist` file.
    /// - Returns: A config with values from `AirshipConfig.plist` file.
    @objc(defaultConfigWithError:)
    public class func `default`() throws -> UAAirshipConfig {
        return UAAirshipConfig(
            config: try AirshipConfig.default()
        )
    }

    /**
     * Creates an instance using the values found in the specified `.plist` file.
     * - Parameter path: The path of the specified file.
     * - Returns: A config with values from the specified file.
     */
    @objc
    public class func fromPlist(contentsOfFile path: String) throws -> UAAirshipConfig {
        return UAAirshipConfig(
            config: try AirshipConfig(fromPlist: path)
        )
    }

    /// Creates an instance with empty values.
    /// - Returns: A config with empty values.
    @objc
    public class func config() -> UAAirshipConfig {
        return UAAirshipConfig(config: AirshipConfig())
    }

    private init(config: AirshipConfig) {
        self.config = config
    }

    /// Validates credentails
    /// - Parameters:
    ///     - inProduction: To validate production or development credentials
    @objc
    public func validateCredentials(inProduction: Bool) throws {
        try self.config.validateCredentials(inProduction: inProduction)
    }
}


@objc
/// Represents the possible log levels.
public enum UAAirshipLogLevel: Int, Sendable {
    /**
     * Undefined log level.
     */
    case undefined = -1

    /**
     * No log messages.
     */
    case none = 0

    /**
     * Log error messages.
     *
     * Used for critical errors, parse exceptions and other situations that cannot be gracefully handled.
     */
    case error = 1

    /**
     * Log warning messages.
     *
     * Used for API deprecations, invalid setup and other potentially problematic situations.
     */
    case warn = 2

    /**
     * Log informative messages.
     *
     * Used for reporting general SDK status.
     */
    case info = 3

    /**
     * Log debugging messages.
     *
     * Used for reporting general SDK status with more detailed information.
     */
    case debug = 4

    /**
     * Log detailed verbose messages.
     *
     * Used for reporting highly detailed SDK status that can be useful when debugging and troubleshooting.
     */
    case verbose = 5
}


@objc
/// Represents the possible sites.
public enum UACloudSite: Int, Sendable {
    /// Represents the US cloud site. This is the default value.
    /// Projects available at go.airship.com must use this value.
    case us = 0
    /// Represents the EU cloud site.
    /// Projects available at go.airship.eu must use this value.
    case eu = 1
}

public class UAHelpers: NSObject {
    
    public static func toLogLevel(level: AirshipLogLevel) -> UAAirshipLogLevel {
        switch(level){
        case AirshipLogLevel.undefined:
            return UAAirshipLogLevel.undefined
        case AirshipLogLevel.none:
            return UAAirshipLogLevel.none
        case AirshipLogLevel.error:
            return UAAirshipLogLevel.error
        case AirshipLogLevel.warn:
            return UAAirshipLogLevel.warn
        case AirshipLogLevel.info:
            return UAAirshipLogLevel.info
        case AirshipLogLevel.debug:
            return UAAirshipLogLevel.debug
        case AirshipLogLevel.verbose:
            return UAAirshipLogLevel.verbose
        default:
            return UAAirshipLogLevel.undefined
        }
    }
    
    public static func toAirshipLogLevel(level: UAAirshipLogLevel) -> AirshipLogLevel {
        switch(level){
        case UAAirshipLogLevel.undefined:
            return AirshipLogLevel.undefined
        case UAAirshipLogLevel.none:
            return AirshipLogLevel.none
        case UAAirshipLogLevel.error:
            return AirshipLogLevel.error
        case UAAirshipLogLevel.warn:
            return AirshipLogLevel.warn
        case UAAirshipLogLevel.info:
            return AirshipLogLevel.info
        case UAAirshipLogLevel.debug:
            return AirshipLogLevel.debug
        case UAAirshipLogLevel.verbose:
            return AirshipLogLevel.verbose
        default:
            return AirshipLogLevel.undefined
        }
    }
    
    public static func toSite(site: CloudSite) -> UACloudSite {
        switch(site){
        case CloudSite.us:
            return UACloudSite.us
        case CloudSite.eu:
            return UACloudSite.eu
        default:
            return UACloudSite.us
        }
    }
    
    public static func toAirshipSite(site: UACloudSite) -> CloudSite {
        switch(site){
        case UACloudSite.us:
            return CloudSite.us
        case UACloudSite.eu:
            return CloudSite.eu
        default:
            return CloudSite.us
        }
    }
    
    public static func toChannelType(type: ChannelType) -> UAChannelType {
        switch(type){
        case ChannelType.email:
            return UAChannelType.email
        case ChannelType.open:
            return UAChannelType.open
        case ChannelType.sms:
            return UAChannelType.sms
        default:
            return UAChannelType.email
        }
    }
    
    public static func toAirshipChannelType(type: UAChannelType) -> ChannelType {
        switch(type){
        case UAChannelType.email:
            return ChannelType.email
        case UAChannelType.open:
            return ChannelType.open
        case UAChannelType.sms:
            return ChannelType.sms
        default:
            return ChannelType.email
        }
    }
    
}
