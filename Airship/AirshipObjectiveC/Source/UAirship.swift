/* Copyright Airship and Contributors */

public import Foundation

#if canImport(UIKit)
public import UIKit
#endif

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Main entry point for Airship. The application must call `takeOff` during `application:didFinishLaunchingWithOptions:`
/// before accessing any instances on Airship or Airship modules.
@objc
public final class UAirship: NSObject, Sendable {

    private static let storage = Storage()
    private static let _push: UAPush = UAPush()
    private static let _channel: UAChannel = UAChannel()
    private static let _contact: UAContact = UAContact()
    private static let _privacyManager: UAPrivacyManager = UAPrivacyManager()
    private static let _messageCenter: UAMessageCenter = UAMessageCenter()
    private static let _preferenceCenter: UAPreferenceCenter = UAPreferenceCenter()
    private static let _analytics: UAAnalytics = UAAnalytics()
    private static let _inAppAutomation: UAInAppAutomation = UAInAppAutomation()
    private static let _permissionsManager: UAPermissionsManager = UAPermissionsManager()

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

    /// Channel instance
    @objc
    public static var channel: UAChannel {
        assertAirshipIsFlying()
        return _channel
    }

    /// Contact instance
    @objc
    public static var contact: UAContact {
        assertAirshipIsFlying()
        return _contact
    }

    /// Contact instance
    @objc
    public static var analytics: UAAnalytics {
        assertAirshipIsFlying()
        return _analytics
    }

    /// Message Center  instance
    @objc
    public static var messageCenter: UAMessageCenter {
        assertAirshipIsFlying()
        return _messageCenter
    }

    /// Preference Center instance
    @objc
    public static var preferenceCenter: UAPreferenceCenter {
        assertAirshipIsFlying()
        return _preferenceCenter
    }

    /// Privacy manager
    @objc
    public static var privacyManager: UAPrivacyManager {
        assertAirshipIsFlying()
        return _privacyManager
    }
    
    /// In App Automation
    @objc
    public static var inAppAutomation: UAInAppAutomation {
        assertAirshipIsFlying()
        return _inAppAutomation
    }

    /// Permissions Manager
    @objc
    public static var permissionsManager: UAPermissionsManager {
        assertAirshipIsFlying()
        return _permissionsManager
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
    @available(*, deprecated, message: "Use Airship.takeOff() instead")
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
    @available(*, deprecated, message: "Use Airship.takeOff(_:) instead")
    public class func takeOff(
        _ config: UAConfig?,
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) throws {
        try Airship.takeOff(config?.config, launchOptions: launchOptions)
    }

#endif

    /// Initializes Airship. Config will be read from `AirshipConfig.plist`.
    @objc
    @MainActor
    public class func takeOff() throws {
        try Airship.takeOff()
    }

    /// Initializes Airship.
    /// - Parameters:
    ///     - config: The Airship config.
    @objc
    @MainActor
    public class func takeOff(_ config: UAConfig?) throws {
        try Airship.takeOff(config?.config)
    }

    @MainActor
    fileprivate final class Storage  {
        var deepLinkDelegate: (any DeepLinkDelegate)?
    }

}

/// NSNotificationCenter keys event names
@objc
public final class UAAirshipNotifications: NSObject {

    /// Notification when Airship is ready.
    @objc(UAAirshipNotificationsAirshipReady)
    public final class UAAirshipReady: NSObject {
        /// Notification name
        @objc
        public static let name = AirshipNotifications.AirshipReady.name

        /// Airship ready channel ID key. Only available if `extendedBroadcastEnabled` is true in config.
        @objc
        public static let channelIDKey = AirshipNotifications.AirshipReady.channelIDKey

        /// Airship ready app key. Only available if `extendedBroadcastEnabled` is true in config.
        @objc
        public static let appKey = AirshipNotifications.AirshipReady.appKey

        /// Airship ready payload version. Only available if `extendedBroadcastEnabled` is true in config.
        @objc
        public static let payloadVersionKey = AirshipNotifications.AirshipReady.payloadVersionKey
    }

    /// Notification when channel is created.
    @objc(UAirshipNotificationChannelCreated)
    public final class UAirshipNotificationChannelCreated: NSObject {
        /// Notification name
        @objc
        public static let name = AirshipNotifications.ChannelCreated.name

        /// NSNotification userInfo key to get the channel ID.
        @objc
        public static let channelIDKey = AirshipNotifications.ChannelCreated.channelIDKey

        /// NSNotification userInfo key to get a boolean if the channel is existing or not.
        @objc
        public static let isExistingChannelKey = AirshipNotifications.ChannelCreated.isExistingChannelKey
    }
}
