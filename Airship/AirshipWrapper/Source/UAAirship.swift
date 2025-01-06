/* Copyright Airship and Contributors */

import Foundation
import AirshipCore



/// Main entry point for Airship. The application must call `takeOff` during `application:didFinishLaunchingWithOptions:`
/// before accessing any instances on Airship or Airship modules.
@objc
public final class UAAirship: NSObject, Sendable {

    private static let storage = Storage()
    private static let _push: UAPush = UAPush()
    private static let _privacyManager: UAPrivacyManager = UAPrivacyManager()
    private static let _messageCenter: UAMessageCenter = UAMessageCenter()

    /// Asserts that Airship is flying (initalized)
    public static func assertAirshipIsFlying() {
        if !Airship.isFlying {
            assertionFailure("TakeOff must be called before accessing Airship.")
        }
    }

    /// Push instance
    @objc
    public static var push: UAPush {
        assertAirshipIsFlying()
        return _push
    }

    /// Push instance
    @objc
    public static var messageCenter: UAMessageCenter {
        assertAirshipIsFlying()
        return _messageCenter
    }


    /// Privacy manager
    @objc
    public static var privacyManager: UAPrivacyManager {
        assertAirshipIsFlying()
        return _privacyManager
    }

    /// A user configurable deep link delegate
    @MainActor
    @objc
    public static var deepLinkDelegate: (any UADeepLinkDelegate)? {
        get {
            assertAirshipIsFlying()
            guard let wrapped = Airship.deepLinkDelegate as? UADeepLinkDelegateWrapper else {
                return nil
            }
            return wrapped.forwardDelegate
        }
        set {
            assertAirshipIsFlying()
            if let newValue {
                let wrapper = UADeepLinkDelegateWrapper(delegate: newValue)
                Airship.deepLinkDelegate = wrapper
                storage.deepLinkDelegate = wrapper
            } else {
                Airship.deepLinkDelegate = nil
                storage.deepLinkDelegate = nil
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
    ) throws {
        try Airship.takeOff(launchOptions: launchOptions)
    }

    /// Initializes Airship.
    /// - Parameters:
    ///     - config: The Airship config.
    ///     - launchOptions: The launch options passed into `application:didFinishLaunchingWithOptions:`.
    @objc
    @MainActor
    public class func takeOff(
        _ config: UAAirshipConfig?,
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) throws {
        try Airship.takeOff(config?.config, launchOptions: launchOptions)
    }

#else

    /// Initializes Airship. Config will be read from `AirshipConfig.plist`.
    @objc
    @MainActor
    public class func takeOff() throws {
        try Airship.takeOff(nil)
    }

    /// Initializes Airship.
    /// - Parameters:
    ///     - config: The Airship config.
    @objc
    @MainActor
    public class func takeOff(_ config: AirshipConfig?) throws {
        try Airship.takeOff(config)
    }
    
#endif

    @MainActor
    fileprivate final class Storage  {
        var deepLinkDelegate: (any DeepLinkDelegate)?
    }

}

/// NSNotificationCenter keys event names
@objc(UAAirshipNotifications)
public final class UAAirshipNotifications: NSObject {

    /// Notification when Airship is ready.
    @objc(UAAirshipNotificationsAirshipReady)
    public final class UAAirshipReady: NSObject {
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
