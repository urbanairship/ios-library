/* Copyright Airship and Contributors */

import Foundation
public import AirshipCore

/**
 * Airship manages the shared state for all Airship services. Airship.takeOff should be
 * called from within your application delegate's `application:didFinishLaunchingWithOptions:` method
 * to initialize the shared instance.
 */

/// Main entry point for Airship. The application must call `takeOff` during `application:didFinishLaunchingWithOptions:`
/// before accessing any instances on Airship or Airship modules.
@objc(OUAAirship)
public class OUAAirship: NSObject {
    
    /// A user configurable deep link delegate.
    private var _deepLinkDelegate: DeepLinkDelegate?
    @objc
    public var deepLinkDelegate: OUADeepLinkDelegate? {
        didSet {
            if let deepLinkDelegate {
                _deepLinkDelegate = OUADeepLinkDelegateWrapper(delegate: deepLinkDelegate)
                Airship.deepLinkDelegate = _deepLinkDelegate
            } else {
                Airship.deepLinkDelegate = nil
            }
        }
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
        Airship.takeOff(launchOptions: launchOptions)
    }

    /// Initializes Airship.
    /// - Parameters:
    ///     - config: The Airship config.
    ///     - launchOptions: The launch options passed into `application:didFinishLaunchingWithOptions:`.
    @objc
    @MainActor
    public class func takeOff(
        _ config: OUAAirshipConfig?,
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) {
        Airship.takeOff(config?.config, launchOptions: launchOptions)
    }

#else

    /// Initializes Airship. Config will be read from `AirshipConfig.plist`.
    @objc
    @MainActor
    public class func takeOff() {
        Airship.takeOff(nil)
    }

    /// Initializes Airship.
    /// - Parameters:
    ///     - config: The Airship config.
    @objc
    @MainActor
    public class func takeOff(_ config: AirshipConfig?) {
        Airship.takeOff(config)
    }
    
#endif
    
}

/// NSNotificationCenter keys event names
@objc(OUAAirshipNotifications)
public final class OUAAirshipNotifications: NSObject {

    /// Notification when Airship is ready.
    @objc(OUAAirshipNotificationsAirshipReady)
    public final class OUAAirshipReady: NSObject {
        /// Notification name
        @objc
        public static let name = NSNotification.Name(
            "com.urbanairship.airship_ready"
        )

        /// Airship ready channel ID key. Only available if `extendedBroadcastEnabled` is true in config.
        @objc
        public static let channelIDKey = "channel_id"

        /// Airship ready app key. Only available if `extendedBroadcastEnabled` is true in config.
        @objc
        public static let appKey = "app_key"

        /// Airship ready payload version. Only available if `extendedBroadcastEnabled` is true in config.
        @objc
        public static let payloadVersionKey = "payload_version"
    }
}
