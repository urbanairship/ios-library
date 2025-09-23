/* Copyright Airship and Contributors */

import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(WatchKit)
import WatchKit
#endif

#if canImport(AirshipBasement)
import AirshipBasement
#endif


/// Main entry point for Airship. The application must call `takeOff` within `application(_:didFinishLaunchingWithOptions:)`
/// before accessing any instances on Airship or Airship modules.
public final class Airship: Sendable {

    /// Airship deep link scheme
    /// - Note: For internal use only. :nodoc:
    public static let deepLinkScheme = "uairship"

    private static let appSettingsDeepLinkHost = "app_settings"

    private static let appStoreDeepLinkHost = "app_store"

    private static let itunesIDKey = "itunesID"

    /// A flag that checks if the Airship instance is available. `true` if available, otherwise `false`.
    public static var isFlying: Bool {
        return Airship._shared != nil
    }

    private let _airshipInstanceHolder: AirshipAtomicValue<any AirshipInstance>
    var airshipInstance: any AirshipInstance {
        _airshipInstanceHolder.value
    }

    /// Airship config.
    public static var config: RuntimeConfig { return shared.airshipInstance.config }

    /// Action registry.
    public static var actionRegistry: ActionRegistry {
        return shared.airshipInstance.actionRegistry
    }

    /// The Airship permissions manager.
    public static var permissionsManager: AirshipPermissionsManager {
        return shared.airshipInstance.permissionsManager
    }

    #if !os(tvOS) && !os(watchOS)

    /// A user configurable UAJavaScriptCommandDelegate
    /// - NOTE: this delegate is not retained.
    public static weak var javaScriptCommandDelegate: (any JavaScriptCommandDelegate)? {
        get {
            return shared.airshipInstance.javaScriptCommandDelegate
        }
        set {
            shared._airshipInstanceHolder.value.javaScriptCommandDelegate = newValue
        }
    }

    /// The channel capture utility.
    public static var channelCapture: ChannelCapture {
        return shared.airshipInstance.channelCapture
    }
    #endif

    /// A user configurable deep link delegate.
    /// - NOTE: this delegate is not retained.
    public static weak var deepLinkDelegate: (any DeepLinkDelegate)? {
        get {
            return shared.airshipInstance.deepLinkDelegate
        }
        set {
            shared._airshipInstanceHolder.value.deepLinkDelegate = newValue
        }
    }

    /// A user configurable deep link handler.
    /// Takes precedence over `deepLinkDelegate` when set.
    @MainActor
    public static var onDeepLink: (@Sendable @MainActor (URL) async -> Void)? {
        get {
            return shared.airshipInstance.onDeepLink
        }
        set {
            shared._airshipInstanceHolder.value.onDeepLink = newValue
        }
    }

    /// The URL allow list used for validating URLs for landing pages,
    /// wallet action, open external URL action, deep link
    /// action (if delegate is not set), and HTML in-app messages.
    public static var urlAllowList: any AirshipURLAllowList {
        return shared.airshipInstance.urlAllowList
    }

    /// The locale manager.
    public static var localeManager: any AirshipLocaleManager {
        return shared.airshipInstance.localeManager
    }

    /// The privacy manager
    public static var privacyManager: any AirshipPrivacyManager {
        return shared.airshipInstance.privacyManager
    }

    static var inputValidator: any AirshipInputValidation.Validator {
        return shared.airshipInstance.inputValidator
    }

    /// - NOTE: For internal use only. :nodoc:
    public var components: [any AirshipComponent] { return airshipInstance.components }

    static let _sharedHolder = AirshipAtomicValue<Airship?>(nil)
    static var _shared: Airship? {
        get { _sharedHolder.value }
        set { _sharedHolder.value = newValue }
    }

    static var shared: Airship {
        if !Airship.isFlying {
            assertionFailure("TakeOff must be called before accessing Airship.")
        }
        return _shared!
    }

    /// Shared Push instance.
    public static var push: any AirshipPush {
        return requireComponent(ofType: (any AirshipPush).self)
    }

    /// Shared Contact instance.
    public static var contact: any AirshipContact {
        return requireComponent(ofType: (any AirshipContact).self)
    }

    /// Shared Analytics instance.
    public static var analytics: any AirshipAnalytics {
        return requireComponent(ofType: (any AirshipAnalytics).self)
    }

    /// Shared Channel instance.
    public static var channel: any AirshipChannel {
        return requireComponent(ofType: (any AirshipChannel).self)
    }

    @MainActor
    private static var onReadyCallbacks: [@MainActor @Sendable () -> Void] = []

    init(instance: any AirshipInstance) {
        self._airshipInstanceHolder = AirshipAtomicValue(instance)
    }

#if !os(watchOS)
    /// Initializes Airship. If any errors are found with the config or if Airship is already initialized it will throw with
    /// the error.
    /// - Parameters:
    ///     - config: The Airship config. If nil, config will be loading from a plist.
    ///     - launchOptions: The launch options passed into `application:didFinishLaunchingWithOptions:`.
    @MainActor
    @available(*, deprecated, message: "Use Airship.takeOff(_:) instead")
    public class func takeOff(
        _ config: AirshipConfig? = nil,
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) throws {
        try commonTakeOff(config) {
#if !os(tvOS) && !os(watchOS)
            if let remoteNotification =
                launchOptions?[
                    UIApplication.LaunchOptionsKey.remoteNotification
                ]
                as? [AnyHashable: Any]
            {
                if AppStateTracker.shared.state != .background {
                    self.requireComponent(ofType: (any InternalAirshipAnalytics).self).launched(
                        fromNotification: remoteNotification
                    )
                }
            }
#endif
        }
    }
#endif

    /// Initializes Airship. If any errors are found with the config or if Airship is already intiialized it will throw with
    /// the error.
    /// - Parameters:
    ///     - config: The Airship config. If nil, config will be loading from a plist.
    @MainActor
    public class func takeOff(
        _ config: AirshipConfig? = nil
    ) throws {
        try commonTakeOff(config)
    }

    /// On ready callback gets called immediately when ready otherwise gets called immediately after takeoff
    /// - Parameter callback: callback closure that's called when Airship is ready
    @MainActor
    public static func onReady(callback: @MainActor @Sendable @escaping () -> Void) {
        onReadyCallbacks.append(callback)

        if isFlying {
            executeOnReady()
        }
    }

    /// Helper method that executes any remaining onReady closures and resets the array
    @MainActor
    private static func executeOnReady() {
        let toExecute = onReadyCallbacks
        onReadyCallbacks.removeAll()
        toExecute.forEach { $0() }
    }


    @MainActor
    private class func configureLogger(_ config: AirshipConfig, inProduction: Bool) {
        let handler = if let logHandler = config.logHandler {
            logHandler
        } else {
            DefaultLogHandler(
                privacyLevel: inProduction ? config.productionLogPrivacyLevel : config.developmentLogPrivacyLevel
            )
        }

        AirshipLogger.configure(
            logLevel: inProduction ? config.productionLogLevel : config.developmentLogLevel,
            handler: handler
        )
    }

    @MainActor
    private class func commonTakeOff(_ config: AirshipConfig?, onReady: (() -> Void)? = nil) throws {
        guard !Airship.isFlying else {
            throw AirshipErrors.error("Airship already initalized. TakeOff can only be called once.")
        }

        // Get the config
        let resolvedConfig = try (config ?? AirshipConfig.default())

        // Determine production flag and configure logger so we can log errors
        var inProduction: Bool = true
        do {
            inProduction = try resolvedConfig.resolveInProduction()
            configureLogger(resolvedConfig, inProduction: inProduction)
        } catch {
            configureLogger(resolvedConfig, inProduction: inProduction)
            AirshipLogger.impError("Unable to determine AirshipConfig.inProduction \(error), defaulting to true")
        }

        let credentials = try resolvedConfig.resolveCredentails(inProduction)

        // We have valid config, log issues
        resolvedConfig.logIssues()

        AirshipLogger.info(
            "Airship TakeOff! SDK Version \(AirshipVersion.version), App Key: \(credentials.appKey), inProduction: \(inProduction)"
        )

        ChallengeResolver.shared.resolver = resolvedConfig.connectionChallengeResolver

        _shared = Airship(
            instance: DefaultAirshipInstance(
                airshipConfig: resolvedConfig,
                appCredentials: credentials
            )
        )

        let integrationDelegate = DefaultAppIntegrationDelegate(
            push: requireComponent(ofType: (any InternalAirshipPush).self),
            analytics: requireComponent(ofType: (any InternalAirshipAnalytics).self),
            pushableComponents: _shared?.components.compactMap {
                return $0 as? (any AirshipPushableComponent)
            } ?? []
        )

        if resolvedConfig.isAutomaticSetupEnabled {
            AirshipLogger.info("Automatic setup enabled.")
            UAAutoIntegration.setLogger { isError, function, line, message in
                AirshipLogger.log(
                    logLevel: isError ? .error : .verbose,
                    message: message(),
                    fileID: "UAAutoIntegration",
                    line: line,
                    function: function
                )
            }
            #if !os(tvOS) && !os(watchOS)
            // Check if app delegate is available for swizzling
            if UIApplication.shared.delegate == nil {
                AirshipLogger.info("App delegate not set, deferring automatic integration until didFinishLaunching.")

                // Defer swizzling until app delegate is available (SwiftUI App.init() case)
                NotificationCenter.default.addObserver(
                    forName: UIApplication.didFinishLaunchingNotification,
                    object: nil,
                    queue: .main
                ) { _ in
                    Task { @MainActor in
                        if UIApplication.shared.delegate != nil {
                            AirshipLogger.info("App delegate now available via didFinishLaunching, performing automatic integration.")
                            UAAutoIntegration.integrate(with: integrationDelegate)
                        } else {
                            AirshipLogger.error("App delegate still not set after didFinishLaunching. Automatic setup skipped.")
                        }
                    }
                }
            } else {
                // App delegate is available, integrate immediately
                UAAutoIntegration.integrate(with: integrationDelegate)
            }
            #else
            // watchOS and tvOS always integrate immediately
            UAAutoIntegration.integrate(with: integrationDelegate)
            #endif
        } else {
            AppIntegration.integrationDelegate = integrationDelegate
        }

        onReady?()

        self.shared.airshipInstance.airshipReady()
        executeOnReady()

        if resolvedConfig.isExtendedBroadcastsEnabled {
            var userInfo: [String: Any] = [:]
            userInfo[AirshipNotifications.AirshipReady.channelIDKey] =
                self.channel.identifier
            userInfo[AirshipNotifications.AirshipReady.appKey] = credentials.appKey
            userInfo[AirshipNotifications.AirshipReady.payloadVersionKey] = 1
            NotificationCenter.default.post(
                name: AirshipNotifications.AirshipReady.name,
                object: userInfo
            )
        } else {
            NotificationCenter.default.post(
                name: AirshipNotifications.AirshipReady.name,
                object: nil
            )
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
    /// `uairship://` deep links will be handled internally. All other deep links will be forwarded to the deep link handler or delegate
    ///  in that order.
    /// - Parameters:
    ///     - deepLink: The deep link.
    ///     - completionHandler: The result. `true` if the link was able to be processed, otherwise `false`.
    @MainActor
    func deepLink(
        _ deepLink: URL
    ) async -> Bool {
        guard deepLink.scheme != Airship.deepLinkScheme else {
            guard handleAirshipDeeplink(deepLink) else {
                let component = self.airshipInstance.components.first(
                    where: { $0.deepLink(deepLink) }
                )

                if component != nil {
                    AirshipLogger.debug("Handling Airship deep link: \(deepLink)")
                    return true
                }

                // Try handler first, then delegate
                if let onDeepLink = self.airshipInstance.onDeepLink {
                    AirshipLogger.debug("Handling deep link via onDeepLink closure: \(deepLink)")
                    await onDeepLink(deepLink)
                    return true
                } else if let deepLinkDelegate = self.airshipInstance.deepLinkDelegate {
                    AirshipLogger.debug("Handling deep link by receivedDeepLink: \(deepLink) on delegate: \(deepLinkDelegate)")
                    await deepLinkDelegate.receivedDeepLink(deepLink)
                    return true
                }

                AirshipLogger.debug("Unhandled deep link \(deepLink)")
                return true
            }
           return true
        }

        // Try handler first, then delegate
        if let deepLinkHandler = self.airshipInstance.onDeepLink {
            AirshipLogger.debug("Handling deep link via onDeepLink closure: \(deepLink)")
            await deepLinkHandler(deepLink)
            return true
        } else if let deepLinkDelegate = self.airshipInstance.deepLinkDelegate {
            AirshipLogger.debug("Handling deep link via receivedDeepLink: \(deepLink) on delegate: \(deepLinkDelegate)")
            await deepLinkDelegate.receivedDeepLink(deepLink)
            return true
        }

        AirshipLogger.debug("Unhandled deep link \(deepLink)")
        return false
    }

    /// Handle the Airship deep links for app_settings and app_store.
    /// - Note: For internal use only. :nodoc:
    /// `uairship://app_settings` and `uairship://app_store?itunesID=<ITUNES_ID>` deep links will be handled internally. If no itunesID provided, use the one in Airship Config.
    /// - Parameters:
    ///     - deepLink: The deep link.
    /// - Returns: `true` if the deeplink is handled, `false` otherwise.
    @MainActor
    private func handleAirshipDeeplink(_ deeplink: URL) -> Bool {

        switch deeplink.host {
        case Airship.appSettingsDeepLinkHost:
            #if !os(watchOS)
            AirshipLogger.debug("Handling Settings deep link: \(deeplink)")
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            #endif
            return true
        case Airship.appStoreDeepLinkHost:
            AirshipLogger.debug("Handling App Store deep link: \(deeplink)")

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
        return queryMap[Airship.itunesIDKey] as? String ?? airshipInstance.config.airshipConfig.itunesID
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
            date = self.airshipInstance.component(ofType: (any AirshipChannel).self)?.identifier != nil ? Date.distantPast : Date()
        }

        self.airshipInstance.preferenceDataStore.setObject(date, forKey: Airship.newUserCutOffDateKey)
        return date
    }
}

/// NSNotificationCenter keys event names
public final class AirshipNotifications {

    /// Notification when Airship is ready.
    public final class AirshipReady {
        /// Notification name
        public static let name = NSNotification.Name(
            "com.urbanairship.airship_ready"
        )

        /// Airship ready channel ID key. Only available if `extendedBroadcastEnabled` is true in config.
        public static let channelIDKey = "channel_id"

        /// Airship ready app key. Only available if `extendedBroadcastEnabled` is true in config.
        public static let appKey = "app_key"

        /// Airship ready payload version. Only available if `extendedBroadcastEnabled` is true in config.
        public static let payloadVersionKey = "payload_version"
    }
}


public extension Airship {

    /// Waits for Airship to be ready using async/await.
    ///
    /// This method provides a modern async/await interface for waiting until Airship
    /// has finished initializing. It's particularly useful when you need to ensure
    /// Airship is ready before performing operations that depend on it.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Wait for Airship to be ready
    /// await Airship.waitForReady()
    ///
    /// // Now safe to use Airship components
    /// Airship.push.enableUserNotifications()
    /// ```
    ///
    /// ## Behavior
    ///
    /// - If Airship is already initialized (`isFlying` is `true`), this method returns immediately
    /// - If Airship is not yet initialized, this method suspends until initialization completes
    /// - The method will not throw or fail - it simply waits for the ready state
    ///
    /// - Note: This method must be called from the main thread.
    /// - Important: This method assumes `Airship.takeOff` has been called. If `takeOff`
    ///   is never called, this method will suspend indefinitely.
    @MainActor
    static func waitForReady() async {
        guard !Airship.isFlying else { return }
        await withCheckedContinuation { continuation in
            Airship.onReady {
                continuation.resume()
            }
        }
    }
    
}

