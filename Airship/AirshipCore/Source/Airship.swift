/* Copyright Airship and Contributors */

import Foundation

/**
 * UAirship manages the shared state for all Airship services. [UAirship takeOff:] should be
 * called from within your application delegate's `application:didFinishLaunchingWithOptions:` method
 * to initialize the shared instance.
 */

/// Main entry point for Airship. The application must call `takeOff` during `application:didFinishLaunchingWithOptions:`
/// before accesing any instances on Airship or Airship modules.
@objc(UAirship)
public class Airship : NSObject {
    
    /// Airship deep link scheme
    @objc
    public static let deepLinkScheme = "uairship"
    
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
    
    /// User defualts key to clear the keychain of Airship values for one app run. Used for testing.
    @objc
    public static let resetKeyChainKey = "com.urbanairship.reset_keychain"

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
    
    #if !os(tvOS)
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
        if (_shared == nil) {
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
        
        guard _shared == nil else {
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
        
        self.logLevel = resolvedConfig.logLevel
        
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

        if let launchOptions = launchOptions {
            if (AppStateTracker.shared.state != .background) {
                analytics.launched(fromNotification: launchOptions)
            }
        }
        
        self.shared.components.forEach { $0.airshipReady?() }
    }
    
    /// Sets the Airship log level. The log level defaults to `.debug` in developer mode,
    /// and `.error` in production. Values set before `takeOff` will be overridden by
    /// the value from the AirshipConfig.
    /// - Parameters:
    ///     - logLevel: The log level. Use .none to disable all logs.
    ///
    @objc
    public static var logLevel: LogLevel = .error {
        didSet {
            uaLogLevel = logLevel.rawValue
            AirshipLogger.logLevel = logLevel
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
            assertionFailure("Misisng required component: \(componentType)")
        }
        return component!
    }

    /// Processes a deep link.
    /// `uairship://` deep links will be handled internally. All other deep links will be forwaded to the deep link delegate.
    /// - Parameters:
    ///     - deepLink: The deep link.
    ///     - completionHandler: The result. `true` if the link was able to be procesed, otherwise `false`.
    @objc
    public func deepLink(_ deepLink: URL, completionHandler: @escaping (Bool) -> Void) {
        guard deepLink.scheme != Airship.deepLinkScheme else {
            _ = self.airshipInstance.components.first(where: { return $0.deepLink?(deepLink) == true })
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
}
