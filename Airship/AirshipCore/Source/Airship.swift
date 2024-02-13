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
/// before accessing any instances on Airship or Airship modules.
@objc(UAirship)
public class Airship: NSObject {

    /// Airship deep link scheme
    /// - Note: For internal use only. :nodoc:
    @objc
    public static let deepLinkScheme = "uairship"

    private static let appSettingsDeepLinkHost = "app_settings"

    private static let appStoreDeepLinkHost = "app_store"

    private static let itunesIDKey = "itunesID"

    /// Notification when Airship is ready.
    @objc
    public static let airshipReadyNotification = NSNotification.Name(
        "com.urbanairship.airship_ready"
    )

    /// Airship ready channel ID key. Only available if `extendedBroadcastEnabled` is true in config.
    @objc
    public static let airshipReadyChannelIdentifier = "channel_id"

    /// Airship ready app key. Only available if `extendedBroadcastEnabled` is true in config.
    @objc
    public static let airshipReadyAppKey = "app_key"

    /// Airship ready payload version. Only available if `extendedBroadcastEnabled` is true in config.
    @objc
    public static let airshipReadyPayloadVersion = "payload_version"

    /// A flag that checks if the Airship instance is available. `true` if available, otherwise `false`.
    @objc
    public static var isFlying: Bool {
        return Airship._shared != nil
    }

    private(set) var airshipInstance: AirshipInstanceProtocol

    /// Airship config.
    @objc
    public var config: RuntimeConfig { return airshipInstance.config }

    /// Action registry.
    public var actionRegistry: ActionRegistry {
        return airshipInstance.actionRegistry
    }

    /// Stores common application metrics such as last open.
    public var applicationMetrics: ApplicationMetrics {
        return airshipInstance.applicationMetrics
    }

    /// The Airship permissions manager.
    @objc
    public var permissionsManager: AirshipPermissionsManager {
        return airshipInstance.permissionsManager
    }

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
    public var channelCapture: ChannelCapture {
        return airshipInstance.channelCapture
    }
    #endif

    /// A user configurable deep link delegate.
    /// - NOTE: this delegate is not retained.
    @objc
    public weak var deepLinkDelegate: DeepLinkDelegate? {
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
    public var urlAllowList: URLAllowList {
        return airshipInstance.urlAllowList
    }

    /// The locale manager.
    @objc
    public var localeManager: AirshipLocaleManager {
        return airshipInstance.localeManager
    }

    /// The privacy manager
    @objc
    public var privacyManager: AirshipPrivacyManager {
        return airshipInstance.privacyManager
    }

    /// - NOTE: For internal use only. :nodoc:
    public var components: [AirshipComponent] { return airshipInstance.components }

    static var _shared: Airship?

    /// Shared Airship instance.
    @objc
    public static var shared: Airship {
        if !Airship.isFlying {
            assertionFailure("TakeOff must be called before accessing Airship.")
        }
        return _shared!
    }

    /// Shared Push instance.
    @objc
    public static var push: AirshipPush { return requireComponent(ofType: AirshipPush.self) }

    /// Shared Contact instance.
    @objc
    public static var contact: AirshipContact {
        return requireComponent(ofType: AirshipContact.self)
    }

    /// Shared Analytics instance.
    @objc
    public static var analytics: AirshipAnalytics {
        return requireComponent(ofType: AirshipAnalytics.self)
    }

    /// Shared Channel instance.
    @objc
    public static var channel: AirshipChannel {
        return requireComponent(ofType: AirshipChannel.self)
    }


    init(instance: AirshipInstanceProtocol) {
        self.airshipInstance = instance
    }

    #if !os(watchOS)

    /// Initializes Airship. Config will be read from `AirshipConfig.plist`.
    /// - Parameters:
    ///     - launchOptions: The launch options passed into `application:didFinishLaunchingWithOptions:`.
    @objc
    @MainActor
    public class func takeOff(
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) {
        takeOff(nil, launchOptions: launchOptions)
    }

    /// Initializes Airship.
    /// - Parameters:
    ///     - config: The Airship config.
    ///     - launchOptions: The launch options passed into `application:didFinishLaunchingWithOptions:`.
    @objc
    @MainActor
    public class func takeOff(
        _ config: AirshipConfig?,
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) {
        guard Thread.isMainThread else {
            fatalError("TakeOff must be called on the main thread.")
        }

        guard !Airship.isFlying else {
            AirshipLogger.impError("TakeOff can only be called once.")
            return
        }

        if config == nil {
            guard
                Bundle.main.path(
                    forResource: "AirshipConfig",
                    ofType: "plist"
                ) != nil
            else {
                AirshipLogger.impError(
                    "AirshipConfig.plist file is missing. Unable to takeOff."
                )
                return
            }
        }

        let resolvedConfig = config?.copy() as? AirshipConfig ?? AirshipConfig.default()

        guard resolvedConfig.validate() else {
            AirshipLogger.impError("Config is invalid. Unable to takeOff.")
            return
        }

        // register transformers
        JSONValueTransformer.register()
        
        commonTakeOff(config)

        #if !os(tvOS) && !os(watchOS)
        if let remoteNotification =
            launchOptions?[
                UIApplication.LaunchOptionsKey.remoteNotification
            ]
            as? [AnyHashable: Any]
        {
            if AppStateTracker.shared.state != .background {
                analytics.launched(fromNotification: remoteNotification)
            }
        }
        #endif

        self.shared.airshipInstance.airshipReady()

        if self.shared.config.isExtendedBroadcastsEnabled {
            var userInfo: [String: Any] = [:]
            userInfo[airshipReadyChannelIdentifier] =
                self.channel.identifier
            userInfo[airshipReadyAppKey] = self.shared.config.appKey
            userInfo[airshipReadyPayloadVersion] = 1
            NotificationCenter.default.post(
                name: airshipReadyNotification,
                object: userInfo
            )
        } else {
            NotificationCenter.default.post(
                name: airshipReadyNotification,
                object: nil
            )
        }
    }

    #else

    /// Initializes Airship. Config will be read from `AirshipConfig.plist`.

    @objc
    @MainActor
    public class func takeOff() {
        takeOff(nil)
    }

    /// Initializes Airship.
    /// - Parameters:
    ///     - config: The Airship config.
    @objc
    @MainActor
    public class func takeOff(_ config: AirshipConfig?) {

        guard Thread.isMainThread else {
            fatalError("TakeOff must be called on the main thread.")
        }

        guard !Airship.isFlying else {
            AirshipLogger.impError("TakeOff can only be called once.")
            return
        }

        if config == nil {
            guard
                Bundle.main.path(
                    forResource: "AirshipConfig",
                    ofType: "plist"
                ) != nil
            else {
                AirshipLogger.impError(
                    "AirshipConfig.plist file is missing. Unable to takeOff."
                )
                return
            }
        }

        let resolvedConfig = config?.copy() as? AirshipConfig ?? AirshipConfig.default()

        guard resolvedConfig.validate() else {
            AirshipLogger.impError("Config is invalid. Unable to takeOff.")
            return
        }

        commonTakeOff(config)

        self.shared.components.forEach { $0.airshipReady() }

        if self.shared.config.isExtendedBroadcastsEnabled {
            var userInfo: [String: Any] = [:]
            userInfo[airshipReadyChannelIdentifier] =
                self.channel.identifier
            userInfo[airshipReadyAppKey] = self.shared.config.appKey
            userInfo[airshipReadyPayloadVersion] = 1
            NotificationCenter.default.post(
                name: airshipReadyNotification,
                object: userInfo
            )
        } else {
            NotificationCenter.default.post(
                name: airshipReadyNotification,
                object: nil
            )
        }
    }

    #endif

    @MainActor
    private class func commonTakeOff(_ config: AirshipConfig?) {

        let resolvedConfig = config?.copy() as? AirshipConfig ?? AirshipConfig.default()

        self.logLevel = resolvedConfig.logLevel

        UALegacyLoggingBridge.logger = { logLevel, function, line, message in
            AirshipLogger.log(
                logLevel: AirshipLogLevel(rawValue: logLevel) ?? .none,
                message: message(),
                fileID: "",
                line: line,
                function: function
            )
        }

        AirshipLogger.info(
            "Airship TakeOff! SDK Version \(AirshipVersion.version), App Key: \(resolvedConfig.appKey), inProduction: \(resolvedConfig.inProduction)"
        )

        _shared = Airship(instance: AirshipInstance(config: resolvedConfig))

        let integrationDelegate = DefaultAppIntegrationDelegate()
        if resolvedConfig.isAutomaticSetupEnabled {
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
    public static var logLevel: AirshipLogLevel {
        get {
            return AirshipLogger.logLevel
        }
        set {
            AirshipLogger.logLevel = newValue
        }
    }

    /// - NOTE: For internal use only. :nodoc:
    public class func component<E>(ofType componentType: E.Type) -> E? {
        return shared.airshipInstance.component(ofType: componentType)
    }

    /// - NOTE: For internal use only. :nodoc:
    public class func requireComponent<E>(ofType componentType: E.Type) -> E {
        let component = shared.airshipInstance.component(
            ofType: componentType
        )

        if component == nil {
            assertionFailure("Missing required component: \(componentType)")
        }
        return component!
    }

    /// - NOTE: For internal use only. :nodoc:
    public class func componentSupplier<E>() -> @Sendable () -> E {
        return {
            return requireComponent(ofType: E.self)
        }
    }

    /// Processes a deep link.
    /// - Note: For internal use only. :nodoc:
    /// `uairship://` deep links will be handled internally. All other deep links will be forwarded to the deep link delegate.
    /// - Parameters:
    ///     - deepLink: The deep link.
    ///     - completionHandler: The result. `true` if the link was able to be processed, otherwise `false`.
    @MainActor
    @objc
    public func deepLink(
        _ deepLink: URL
    ) async -> Bool {
        guard deepLink.scheme != Airship.deepLinkScheme else {
            guard handleAirshipDeeplink(deepLink) else {
                let component = self.airshipInstance.components.first(
                    where: { $0.deepLink(deepLink) }
                )

                if component != nil {
                    return true
                }

                if let deepLinkDelegate = self.airshipInstance.deepLinkDelegate {
                    await deepLinkDelegate.receivedDeepLink(deepLink)
                    return true
                }

                AirshipLogger.debug("Unhandled deep link \(deepLink)")
                return true
            }
           return true
        }

        guard
            let deepLinkDelegate = self.airshipInstance.deepLinkDelegate
        else {
            AirshipLogger.debug("Unhandled deep link \(deepLink)")
            return  false
        }

        await deepLinkDelegate.receivedDeepLink(deepLink)
        
        return true
    }

    /// Handle the Airship deep links for app_settings and app_store.
    /// - Note: For internal use only. :nodoc:
    /// `uairship://app_settings` and `uairship://app_store?itunesID=<ITUNES_ID>` deep links will be handled internally. If no itunesID provided, use the one in Airship Config.
    /// - Parameters:
    ///     - deepLink: The deep link.
    /// - Returns: `true` if the deeplink is handled, `false` otherwise.
    @MainActor
    @objc
    private func handleAirshipDeeplink(_ deeplink: URL) -> Bool {
        switch deeplink.host {
        case Airship.appSettingsDeepLinkHost:
            #if !os(watchOS)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            #endif
            return true
        case Airship.appStoreDeepLinkHost:
            let appStoreUrl = "itms-apps://itunes.apple.com/app/"
            guard let itunesID = getItunesID(deeplink) else {
                return true
            }
            if let url = URL(string: appStoreUrl + itunesID) {
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
        let urlComponents = URLComponents(
            url: deeplink,
            resolvingAgainstBaseURL: false
        )
        let queryMap =
            urlComponents?.queryItems?
            .reduce(into: [String: String?]()) {
                $0[$1.name] = $1.value
            } ?? [:]
        return queryMap[Airship.itunesIDKey] as? String ?? config.itunesID
    }


    // Taken from IAA so we can continue to use the existing value if set
    private static let newUserCutOffDateKey = "UAInAppRemoteDataClient.ScheduledNewUserCutoffTime"

    var installDate: Date {
        if let date = self.airshipInstance.preferenceDataStore.value(forKey: Airship.newUserCutOffDateKey) as? Date {
            return date
        }

        var date: Date!

        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last,
           let attributes = try? FileManager.default.attributesOfItem(atPath: documentsURL.path),
           let installDate = attributes[.creationDate] as? Date
        {
            date = installDate
        } else {
            date = self.airshipInstance.component(ofType: AirshipChannel.self)?.identifier != nil ? Date.distantPast : Date()
        }

        self.airshipInstance.preferenceDataStore.setObject(date, forKey: Airship.newUserCutOffDateKey)
        return date
    }
}
