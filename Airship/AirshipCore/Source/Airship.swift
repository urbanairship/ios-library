/* Copyright Airship and Contributors */

import Foundation
#if os(watchOS)
import WatchKit
#endif

#if canImport(AirshipBasement)
@_exported import AirshipBasement
#endif

/**
 * Airship manages the shared state for all Airship services. Airship.takeOff should be
 * called from within your application delegate's `application:didFinishLaunchingWithOptions:` method
 * to initialize the shared instance.
 */

/// Main entry point for Airship. The application must call `takeOff` during `application:didFinishLaunchingWithOptions:`
/// before accesing any instances on Airship or Airship modules.
@objc(UAirship)
public class Airship : NSObject {
    
    /// Airship deep link scheme
    /// - Note: For internal use only. :nodoc:
    @objc
    public static let deepLinkScheme = "uairship"
    
    private static let appSettingsDeepLinkHost = "app_settings"

    private static let appStoreDeepLinkHost = "app_store"
    
    private static let itunesIDKey = "itunesID"
    
    /// Notification when Airship is ready.
    @objc
    public static let airshipReadyNotification = NSNotification.Name("com.urbanairship.airship_ready")
    
    /// Airship ready channel ID key. Only available if `extendedBroadcastEnabled` is true in config.
    @objc
    public static let airshipReadyChannelIdentifier = "channel_id"
    
    /// Airship ready app key. Only avaialble if `extendedBroadcastEnabled` is true in config.
    @objc
    public static let airshipReadyAppKey = "app_key"
    
    /// Airship ready payload version. Only available if `extendedBroadcastEnabled` is true in config.
    @objc
    public static let airshipReadyPayloadVersion = "payload_version"
    
    /// User defualts key to clear the keychain of Airship values for one app run. Used for testing. :nodoc:
    @objc
    public static let resetKeyChainKey = "com.urbanairship.reset_keychain"
    
    /// A flag that checks if the Airship instance is available. `true` if available, otherwise `false`.
    @objc
    public static var isFlying : Bool {
        get {
            return Airship._shared != nil
        }
    }
    
    private (set) var airshipInstance: AirshipInstanceProtocol
    
    /// Airship config.
    @objc
    public var config: RuntimeConfig { return airshipInstance.config }
    
    /// Action registry.
    @objc
    public var actionRegistry: ActionRegistry  { return airshipInstance.actionRegistry }
    
    /// Stores common application metrics such as last open.
    @objc
    public var applicationMetrics: ApplicationMetrics  { return airshipInstance.applicationMetrics }
    
    /// The Airship location provider. Requires the `AirshipLocation`
    /// module, otherwise nil.
    /// - Note: For internal use only. :nodoc:
    @objc
    public var locationProvider: UALocationProvider? { return airshipInstance.locationProvider }

    /// The Airship permissions manager.
    @objc
    public var permissionsManager: PermissionsManager { return airshipInstance.permissionsManager }

    #if !os(tvOS) && !os(watchOS)
    
    /// A user configurable UAJavaScriptCommandDelegate
    /// - NOTE: this delegate is not retained.
    @objc
    public weak var javaScriptCommandDelegate: JavaScriptCommandDelegate? {
        get {
            return airshipInstance.javaScriptCommandDelegate
        }
        set {
            airshipInstance.javaScriptCommandDelegate = newValue
        }
    }
    
    /// The channel capture utility.
    @objc
    public var channelCapture: ChannelCapture { return airshipInstance.channelCapture }
    #endif
    
    /// A user configurable deep link delegate.
    /// - NOTE: this delegate is not retained.
    @objc
    public weak var deepLinkDelegate: DeepLinkDelegate?  {
        get {
            return airshipInstance.deepLinkDelegate
        }
        set {
            airshipInstance.deepLinkDelegate = newValue
        }
    }
    
    /// The URL allow list used for validating URLs for landing pages,
    /// wallet action, open external URL action, deep link
    /// action (if delegate is not set), and HTML in-app messages.
    @objc(URLAllowList)
    public var urlAllowList : URLAllowList { return airshipInstance.urlAllowList }
    
    /// The locale manager.
    @objc
    public var localeManager: LocaleManager { return airshipInstance.localeManager }
    
    /// The privacy manager
    @objc
    public var privacyManager: PrivacyManager { return airshipInstance.privacyManager }
    
    
    /// - NOTE: For internal use only. :nodoc:
    @objc
    public var components: [Component] { return airshipInstance.components }

    static var _shared: Airship?
    
    /// Shared Airship instance.
    @objc
    public static var shared: Airship {
        if (!Airship.isFlying) {
            assertionFailure("TakeOff must be called before accessing Airship.")
        }
        return _shared!
    }
    
    /// Shared Push instance.
    @objc
    public static var push: Push { return requireComponent(ofType: Push.self) }
    
    /// Shared Contact instance.
    @objc
    public static var contact: Contact { return requireComponent(ofType: Contact.self) }
    
    /// Shared Analytics instance.
    @objc
    public static var analytics: Analytics { return requireComponent(ofType: Analytics.self) }
    
    /// Shared Channel instance.
    @objc
    public static var channel: Channel { return requireComponent(ofType: Channel.self) }
    
    /// Shared NamedUser instance.
    @objc
    public static var namedUser: NamedUser { return requireComponent(ofType: NamedUser.self) }

    init(instance: AirshipInstanceProtocol) {
        self.airshipInstance = instance
    }
    
    #if !os(watchOS)
    
    /// Initalizes Airship. Config will be read from `AirshipConfig.plist`.
    /// - Parameters:
    ///     - launchOptions: The launch options passed into `application:didFinishLaunchingWithOptions:`.
    @objc
    public class func takeOff(launchOptions: [UIApplication.LaunchOptionsKey : Any]?) {
        takeOff(nil, launchOptions: launchOptions)
    }
    
    /// Initalizes Airship.
    /// - Parameters:
    ///     - config: The Airship config.
    ///     - launchOptions: The launch options passed into `application:didFinishLaunchingWithOptions:`.
    @objc
    public class func takeOff(_ config: Config?, launchOptions: [UIApplication.LaunchOptionsKey : Any]?) {
        guard Thread.isMainThread else {
            fatalError("TakeOff must be called on the main thread.")
        }
        
        guard !Airship.isFlying else {
            AirshipLogger.impError("TakeOff can only be called once.")
            return
        }
        
        
        if (config == nil) {
            guard Bundle.main.path(forResource: "AirshipConfig", ofType: "plist") != nil else {
                AirshipLogger.impError("AirshipConfig.plist file is missing. Unable to takeOff.")
                return
            }
        }
        
        let resolvedConfig = config?.copy() as? Config ?? Config.default()
        
        guard resolvedConfig.validate() else {
            AirshipLogger.impError("Config is invalid. Unable to takeOff.")
            return
        }
        
        commonTakeOff(config)
        
        #if !os(tvOS) && !os(watchOS)
        if let remoteNotification = launchOptions?[UIApplication.LaunchOptionsKey.remoteNotification] as? [AnyHashable : Any] {
            if (AppStateTracker.shared.state != .background) {
                analytics.launched(fromNotification: remoteNotification)
            }
        }
        #endif
        
        self.shared.components.forEach { $0.airshipReady?() }

        if (self.shared.config.isExtendedBroadcastsEnabled) {
            var userInfo: [String: Any] = [:]
            userInfo[airshipReadyChannelIdentifier] = self.channel.identifier
            userInfo[airshipReadyAppKey] = self.shared.config.appKey
            userInfo[airshipReadyPayloadVersion] = 1
            NotificationCenter.default.post(name: airshipReadyNotification, object: userInfo)
        } else {
            NotificationCenter.default.post(name: airshipReadyNotification, object: nil)
        }
    }
    
    #else
    
    /// Initalizes Airship. Config will be read from `AirshipConfig.plist`.

    @objc
    public class func takeOff() {
        takeOff(nil)
    }
    
    /// Initalizes Airship.
    /// - Parameters:
    ///     - config: The Airship config.
    @objc
    public class func takeOff(_ config: Config?) {
            
        guard Thread.isMainThread else {
            fatalError("TakeOff must be called on the main thread.")
        }
        
        guard !Airship.isFlying else {
            AirshipLogger.impError("TakeOff can only be called once.")
            return
        }
        
        if (config == nil) {
            guard Bundle.main.path(forResource: "AirshipConfig", ofType: "plist") != nil else {
                AirshipLogger.impError("AirshipConfig.plist file is missing. Unable to takeOff.")
                return
            }
        }
        
        let resolvedConfig = config?.copy() as? Config ?? Config.default()
        
        guard resolvedConfig.validate() else {
            AirshipLogger.impError("Config is invalid. Unable to takeOff.")
            return
        }
        
        commonTakeOff(config)
        
        self.shared.components.forEach { $0.airshipReady?() }

        if (self.shared.config.isExtendedBroadcastsEnabled) {
            var userInfo: [String: Any] = [:]
            userInfo[airshipReadyChannelIdentifier] = self.channel.identifier
            userInfo[airshipReadyAppKey] = self.shared.config.appKey
            userInfo[airshipReadyPayloadVersion] = 1
            NotificationCenter.default.post(name: airshipReadyNotification, object: userInfo)
        } else {
            NotificationCenter.default.post(name: airshipReadyNotification, object: nil)
        }
    }
    
    #endif
    
    private class func commonTakeOff(_ config: Config?) {
        
        let resolvedConfig = config?.copy() as? Config ?? Config.default()
       
        self.logLevel = resolvedConfig.logLevel

        UALegacyLoggingBridge.logger = { logLevel, function, line, message in
            AirshipLogger.log(logLevel: LogLevel(rawValue: logLevel) ?? .none,
                              message: message(),
                              fileID: "",
                              line: line,
                              function: function)
        }
        
        AirshipLogger.info("Airship TakeOff! SDK Version \(AirshipVersion.get()), App Key: \(resolvedConfig.appKey), inProduction: \(resolvedConfig.inProduction)")
        
        // Clearing the key chain
        if (UserDefaults.standard.bool(forKey: resetKeyChainKey) == true) {
            AirshipLogger.debug("Deleting the keychain credentials")
            UAKeychainUtils.deleteKeychainValue(resolvedConfig.appKey)
            UserDefaults.standard.removeObject(forKey: resetKeyChainKey)
        }
        
        _shared = Airship(instance: AirshipInstance(config: resolvedConfig))
        
        let integrationDelegate = DefaultAppIntegrationDelegate()
        if (resolvedConfig.isAutomaticSetupEnabled) {
            AirshipLogger.info("Automatic setup enabled.")
            UAAutoIntegration.integrate(with: integrationDelegate)
        } else {
            AppIntegration.integrationDelegate = integrationDelegate
        }
        
    }

    /// Airship log handler. All Airship log will be routed through the handler.
    ///
    /// The default logger will os.Logger on iOS 14+, and `print` on older devices.
    ///
    /// Custom loggers should be set before takeOff.
    @objc
    public static var logHandler: AirshipLogHandler {
        get {
            return AirshipLogger.logHandler
        }
        set {
            AirshipLogger.logHandler = newValue
        }
    }

    /// Airship log level. The log level defaults to `.debug` in developer mode,
    /// Sets the Airship log level. The log level defaults to `.debug` in developer mode,
    /// and `.error` in production. Values set before `takeOff` will be overridden by
    /// the value from the AirshipConfig.
    @objc
    public static var logLevel: LogLevel {
        get {
            return AirshipLogger.logLevel
        }
        set {
            AirshipLogger.logLevel = newValue
        }
    }
    
    /// - NOTE: For internal use only. :nodoc:
    @objc
    public class func component(forClassName className: String) -> Component? {
        return shared.airshipInstance.component(forClassName: className)
    }
    
    /// - NOTE: For internal use only. :nodoc:
    public class func component<E>(ofType componentType: E.Type) -> E? {
        return shared.airshipInstance.component(ofType: componentType)
    }
    
    /// - NOTE: For internal use only. :nodoc:
    public class func requireComponent<E>(ofType componentType: E.Type) -> E {
        let component = shared.airshipInstance.component(ofType: componentType)
        
        if (component == nil) {
            assertionFailure("Missing required component: \(componentType)")
        }
        return component!
    }

    /// Processes a deep link.
    /// - Note: For internal use only. :nodoc:
    /// `uairship://` deep links will be handled internally. All other deep links will be forwaded to the deep link delegate.
    /// - Parameters:
    ///     - deepLink: The deep link.
    ///     - completionHandler: The result. `true` if the link was able to be procesed, otherwise `false`.
    @objc
    public func deepLink(_ deepLink: URL, completionHandler: @escaping (Bool) -> Void) {
        guard deepLink.scheme != Airship.deepLinkScheme else {
            guard handleAirshipDeeplink(deepLink) else {
                _ = self.airshipInstance.components.first(where: { return $0.deepLink?(deepLink) == true })
                completionHandler(true)
                return
            }
            completionHandler(true)
            return
        }
        
        guard let deepLinkDelegate = self.airshipInstance.deepLinkDelegate else {
            completionHandler(false)
            return
        }
        
        deepLinkDelegate.receivedDeepLink(deepLink) {
            completionHandler(true)
        }        
    }
    
    /// Handle the Airship deep links for app_settings and app_store.
    /// - Note: For internal use only. :nodoc:
    /// `uairship://app_settings` and `uairship://app_store?itunesID=<ITUNES_ID>` deep links will be handled internally. If no itunesID provided, use the one in Airship Config.
    /// - Parameters:
    ///     - deepLink: The deep link.
    /// - Returns: `true` if the deeplink is handled, `false` otherwise.
    @objc
    private func handleAirshipDeeplink(_ deeplink: URL) -> Bool {
        
        switch(deeplink.host) {
        case Airship.appSettingsDeepLinkHost:
            #if !os(watchOS)
            if let url = URL(string:UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            #endif
            return true
        case Airship.appStoreDeepLinkHost:
            let appStoreUrl = "itms-apps://itunes.apple.com/app/"
            guard let itunesID = getItunesID(deeplink) else {
                return true
            }
            if let url = URL(string:appStoreUrl + itunesID) {
                #if !os(watchOS)
                UIApplication.shared.open(url)
                #else
                WKExtension.shared().openSystemURL(url)
                #endif
            }
            return true
        default:
            return false
        }
        
      
    }
    
    /// Gets the iTunes ID.
    /// - Note: For internal use only. :nodoc:
    /// - Parameters:
    ///     - deepLink: The deep link.
    /// - Returns: The iTunes ID or `nil` if it's not set.
    private func getItunesID(_ deeplink: URL) -> String? {
        let urlComponents = URLComponents(url: deeplink, resolvingAgainstBaseURL: false)
        let queryMap = urlComponents?.queryItems?.reduce(into: [String : String?]()) {
            $0[$1.name] = $1.value
        } ?? [:]
        return queryMap[Airship.itunesIDKey] as? String ?? config.itunesID
    }
}
