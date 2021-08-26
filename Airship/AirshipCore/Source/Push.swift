/* Copyright Airship and Contributors */

import Foundation
import UserNotifications

//---------------------------------------------------------------------------------------
// RegistrationDelegate
//---------------------------------------------------------------------------------------
/// Implement this protocol and add as a Push.registrationDelegate to receive
/// registration success and failure callbacks.
///
@objc(UARegistrationDelegate)
public protocol RegistrationDelegate: NSObjectProtocol {
    #if !os(tvOS)
    /// Called when APNS registration completes.
    ///
    /// - Parameters:
    ///   - authorizedSettings: The settings that were authorized at the time of registration.
    ///   - categories: Set of the categories that were most recently registered.
    ///   - status: The authorization status.
    @objc
    optional func notificationRegistrationFinished(
            withAuthorizedSettings authorizedSettings: UAAuthorizedNotificationSettings,
            categories: Set<UNNotificationCategory>,
            status: UAAuthorizationStatus
        )
    #endif

    /// Called when APNS registration completes.
    ///
    /// - Parameters:
    ///   - authorizedSettings: The settings that were authorized at the time of registration.
    ///   - status: The authorization status.
    @objc
    optional func notificationRegistrationFinished(
            withAuthorizedSettings authorizedSettings: UAAuthorizedNotificationSettings,
            status: UAAuthorizationStatus
        )

    /// Called when notification authentication changes with the new authorized settings.
    ///
    /// - Parameter authorizedSettings: UAAuthorizedNotificationSettings The newly changed authorized settings.
    @objc optional func notificationAuthorizedSettingsDidChange(_ authorizedSettings: UAAuthorizedNotificationSettings)

    /// Called when the UIApplicationDelegate's application:didRegisterForRemoteNotificationsWithDeviceToken:
    /// delegate method is called.
    ///
    /// - Parameter deviceToken: The APNS device token.
    @objc optional func apnsRegistrationSucceeded(withDeviceToken deviceToken: Data)

    /// Called when the UIApplicationDelegate's application:didFailToRegisterForRemoteNotificationsWithError:
    /// delegate method is called.
    ///
    /// - Parameter error: An NSError object that encapsulates information why registration did not succeed.
    @objc optional func apnsRegistrationFailedWithError(_ error: Error)
}

//---------------------------------------------------------------------------------------
// PushNotificationDelegate Protocol
//---------------------------------------------------------------------------------------
/// Protocol to be implemented by push notification clients. All methods are optional.
@objc(UAPushNotificationDelegate)
public protocol PushNotificationDelegate: NSObjectProtocol {
    /// Called when a notification is received in the foreground.
    ///
    /// - Parameters:
    ///   - userInfo: The notification info
    ///   - completionHandler: the completion handler to execute when notification processing is complete.
    @objc
    optional func receivedForegroundNotification(_ userInfo: [AnyHashable : Any], completionHandler: @escaping () -> Void)
    /// Called when a notification is received in the background.
    ///
    /// - Parameters:
    ///   - userInfo: The notification info
    ///   - completionHandler: the completion handler to execute when notification processing is complete.
    @objc
    optional func receivedBackgroundNotification(_ userInfo: [AnyHashable : Any], completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
    #if !os(tvOS)
    /// Called when a notification is received in the background or foreground and results in a user interaction.
    /// User interactions can include launching the application from the push, or using an interactive control on the notification interface
    /// such as a button or text field.
    ///
    /// - Parameters:
    ///   - notificationResponse: UNNotificationResponse object representing the user's response
    /// to the notification and the associated notification contents.
    ///
    ///   - completionHandler: the completion handler to execute when processing the user's response has completed.
    @objc
    optional func receivedNotificationResponse(_ notificationResponse: UNNotificationResponse, completionHandler: @escaping () -> Void)
    #endif
    /// Called when a notification has arrived in the foreground and is available for display.
    ///
    /// - Parameters:
    ///   - options: The notification presentation options.
    ///   - notification: The notification.
    /// - Returns: a UNNotificationPresentationOptions enum value indicating the presentation options for the notification.
    @objc(extendPresentationOptions:notification:)
    optional func extend(_ options: UNNotificationPresentationOptions, notification: UNNotification) -> UNNotificationPresentationOptions
}

//---------------------------------------------------------------------------------------
// UAPush Class
//---------------------------------------------------------------------------------------

/// This singleton provides an interface to the functionality provided by the Airship iOS Push API.
@objc(UAPush)
public class Push: UAComponent, PushProtocol {

    // MARK: - Constants

    /// NSNotification event when a notification response is received.
    /// The event will contain the notification response object.
    @objc
    public static let ReceivedNotificationResponseEvent = NSNotification.Name("com.urbanairship.push.received_notification_response")

    /// Response key for ReceivedNotificationResponseEvent
    @objc
    public static let ReceivedNotificationResponseEventResponseKey = "response"

    /// NSNotification event when a foreground notification is received.
    /// The event will contain the payload dictionary as user info.
    @objc
    public static let ReceivedForegroundNotificationEvent = NSNotification.Name("com.urbanairship.push.received_foreground_notification")

    /// NSNotification event when a background notification is received.
    /// The event will contain the payload dictionary as user info.
    @objc
    public static let ReceivedBackgroundNotificationEvent = NSNotification.Name("com.urbanairship.push.received_background_notification")

    // Quiet Time dictionary start key
    @objc
    public static let QuietTimeStartKey = "start"

    // Quiet Time dictionary end key
    @objc
    public static let QuietTimeEndKey = "end"

    // Legacy tag settings key. For internal use only :nodoc:
    @objc
    public static let LegacyTagsSettingsKey = "UAPushTags"

    // Push tags migrated settings key. For internal use only. :nodoc:
    @objc
    public static let TagsMigratedToChannelTagsKey = "UAPushTagsMigrated"

    private static let PushNotificationsOptionsKey = "UAUserPushNotificationsOptions";
    private static let UserPushNotificationsEnabledKey = "UAUserPushNotificationsEnabled"
    private static let BackgroundPushNotificationsEnabledKey = "UABackgroundPushNotificationsEnabled"
    private static let ExtendedPushNotificationPermissionEnabledKey = "UAExtendedPushNotificationPermissionEnabled"

    private static let BadgeSettingsKey = "UAPushBadge"
    private static let DeviceTokenKey = "UADeviceToken"
    private static let QuietTimeSettingsKey = "UAPushQuietTime"
    private static let QuietTimeEnabledSettingsKey = "UAPushQuietTimeEnabled"
    private static let TimeZoneSettingsKey = "UAPushTimeZone"

    private static let TypesAuthorizedKey = "UAPushTypesAuthorized"
    private static let AuthorizationStatusKey = "UAPushAuthorizationStatus"
    private static let UserPromptedForNotificationsKey = "UAPushUserPromptedForNotifications"

    // Old push enabled key
    private static let OldPushEnabledKey = "UAPushEnabled"
    
    // The default device tag group.
    private static let DefaultDeviceTagGroup = "device"

    // The foreground presentation options that can be defined from API or dashboard
    private static let PresentationOptionBadge = "badge"
    private static let PresentationOptionAlert = "alert"
    private static let PresentationOptionSound = "sound"
    private static let PresentationOptionList = "list"
    private static let PresentationOptionBanner = "banner"

    // Foreground presentation keys
    private static let ForegroundPresentationLegacykey = "foreground_presentation"
    private static let ForegroundPresentationkey = "com.urbanairship.foreground_presentation"
    private static let DeviceTokenRegistrationWaitTime: TimeInterval = 10

    // MARK: - Internal Properties

    /// Indicates whether APNS registration is out of date or not.
    private var shouldUpdateAPNSRegistration: Bool
    /// The preference data store.
    private var dataStore: UAPreferenceDataStore

    /// The push registration instance.
    private let pushRegistration: APNSRegistrationProtocol

    private var dispatcher: UADispatcher
    private var application: UIApplication
    private var notificationCenter: NotificationCenter
    private var config: RuntimeConfig
    private var channel: ChannelProtocol
    private var appStateTracker: UAAppStateTracker
    private var waitForDeviceToken = false
    private var privacyManager: UAPrivacyManager
    private var pushEnabled = false
    private var deviceTokenAvailableBlock: (() -> Void)?

    #if !os(tvOS)
    private var _customCategories: Set<UNNotificationCategory> = []
    #endif

    private var isRegisteredForRemoteNotifications: Bool {
        get {
            var registered = false;
            let application = self.application

            self.dispatcher.doSync {
                registered = application.isRegisteredForRemoteNotifications;
            }

            return registered;
        }
    }

    private var isBackgroundRefreshStatusAvailable: Bool {
        get {
            var available = false;
            let application = self.application

            self.dispatcher.doSync {
                available = application.backgroundRefreshStatus == .available;
            };

            return available;
        }
    }

    @objc
    public convenience init(config: RuntimeConfig, dataStore: UAPreferenceDataStore, channel:  ChannelProtocol, analytics: UAAnalytics & UAExtendableAnalyticsHeaders, privacyManager: UAPrivacyManager) {
        self.init(config: config, dataStore: dataStore, channel: channel, analytics: analytics, appStateTracker: UAAppStateTracker.shared, notificationCenter: NotificationCenter.default, pushRegistration: UAAPNSRegistration(), application: UIApplication.shared, dispatcher: UADispatcher.main, privacyManager: privacyManager)
    }

    // MARK: - Initialization

    @objc
    public init(config: RuntimeConfig, dataStore: UAPreferenceDataStore, channel:  ChannelProtocol, analytics: UAAnalytics & UAExtendableAnalyticsHeaders, appStateTracker: UAAppStateTracker, notificationCenter: NotificationCenter, pushRegistration: APNSRegistrationProtocol,  application: UIApplication, dispatcher: UADispatcher, privacyManager: UAPrivacyManager) {
        self.config = config
        self.application = application
        self.dispatcher = dispatcher
        self.channel = channel
        self.dataStore = dataStore
        self.privacyManager = privacyManager
        self.appStateTracker = appStateTracker
        self.notificationCenter = notificationCenter
        self.pushRegistration = pushRegistration
        self.requireAuthorizationForDefaultCategories = true
        self.shouldUpdateAPNSRegistration = true;
        self.defaultPresentationOptions = []

        super.init(dataStore: dataStore)

        self.observeNotificationCenterEvents()

        // Migrate push tags to channel tags
        self.migratePushTagsToChannelTags()
        self.waitForDeviceToken = self.channel.identifier == nil;

        self.channel.addRegistrationExtender { payload, completionHandler in
            self.extendChannelRegistrationPayload(payload, completionHandler: completionHandler)
        }

        analytics.add {
            return self.analyticsHeaders()
        }

        self.updatePushEnablement()
    }

    /// Migrates legacy push tags to channel tags. For internal use only. :nodoc:
    @objc
    public func migratePushTagsToChannelTags() {
        guard self.dataStore.keyExists(Push.LegacyTagsSettingsKey) else {
            // Nothing to migrate
            return
        }

        guard !self.dataStore.bool(forKey: Push.TagsMigratedToChannelTagsKey) else {
            // Already migrated tags
            return
        }

        // Normalize tags for older SDK versions, and migrate to UAChannel as necessary
        if let existingPushTags = self.dataStore.object(forKey: Push.LegacyTagsSettingsKey) as? [String] {
            let existingChannelTags = self.channel.tags
            if existingChannelTags.count > 0 {
                let combinedTagsSet = Set(existingPushTags).union(Set(existingChannelTags))
                self.channel.tags = Array(combinedTagsSet)
            } else {
                self.channel.tags = AudienceUtils.normalizeTags(existingPushTags)
            }
        }

        self.dataStore.setBool(true, forKey: Push.TagsMigratedToChannelTagsKey)
        self.dataStore.removeObject(forKey: Push.LegacyTagsSettingsKey)
    }

    private func observeNotificationCenterEvents() {
        self.notificationCenter.addObserver(self,
                                            selector: #selector(applicationBackgroundRefreshStatusChanged),
                                            name: UIApplication.backgroundRefreshStatusDidChangeNotification,
                                            object: nil)
        self.notificationCenter.addObserver(self,
                                            selector: #selector(applicationDidTransitionToForeground),
                                            name: UAAppStateTracker.didTransitionToForeground,
                                            object: nil)

        self.notificationCenter.addObserver(self,
                                            selector: #selector(applicationDidEnterBackground),
                                            name: UAAppStateTracker.didEnterBackgroundNotification,
                                            object: nil)

        self.notificationCenter.addObserver(self,
                                            selector: #selector(onEnabledFeaturesChanged),
                                            name: UAPrivacyManager.changeEvent,
                                            object: nil)
    }

    // MARK: - Push Notifications

    /// Enables/disables background remote notifications on this device through Airship.
    /// Defaults to `true`.
    @objc
    public var backgroundPushNotificationsEnabled: Bool {
        set {
            let previous = self.backgroundPushNotificationsEnabled
            self.dataStore.setBool(newValue, forKey: Push.BackgroundPushNotificationsEnabledKey)
            if !previous == newValue {
                self.shouldUpdateAPNSRegistration = true
                self.updateRegistration()
            }
        }

        get {
            return self.dataStore.bool(forKey: Push.BackgroundPushNotificationsEnabledKey)
        }
    }

    /// Enables/disables user notifications on this device through Airship.
    /// Defaults to `false`. Once set to `true`, the user will be prompted for remote notifications.
    @objc
    public var userPushNotificationsEnabled: Bool {
        set {
            let previous = self.userPushNotificationsEnabled
            self.dataStore.setBool(newValue, forKey: Push.UserPushNotificationsEnabledKey)
            if !previous == newValue {
                self.shouldUpdateAPNSRegistration = true
                self.updateRegistration()
            }

        }

        get {
            return self.dataStore.bool(forKey: Push.UserPushNotificationsEnabledKey)
        }
    }

    /// Enables/disables extended App Clip user notifications on this device through Airship.
    /// Defaults to `false`. Once set to `true`, the user will be prompted for remote notifications.
    /// - Warning: This property should only be set in an App Clip context. In all other cases, setting it to any value will have no effect.
    /// If userPushNotificationsEnabled is set to 'false' , setting this property will have no effect.
    @objc
    public var extendedPushNotificationPermissionEnabled: Bool {
        set {
            guard self.userPushNotificationsEnabled else {
                return
            }

            let previous = self.extendedPushNotificationPermissionEnabled
            self.dataStore.setBool(newValue, forKey: Push.ExtendedPushNotificationPermissionEnabledKey)

            if newValue && newValue != previous {
                self.shouldUpdateAPNSRegistration = true
                self.updateRegistration()
            }
        }

        get {
            return self.dataStore.bool(forKey: Push.ExtendedPushNotificationPermissionEnabledKey)
        }
    }

    /// The device token for this device, as a hex string.
    @objc
    public private(set) var deviceToken: String? {
        set {
            guard let deviceToken = newValue else {
                self.willChangeValue(forKey: "deviceToken")
                self.dataStore.removeObject(forKey: Push.DeviceTokenKey);
                self.didChangeValue(forKey: "deviceToken");
                return
            }

            do {
                let regex =  try NSRegularExpression(pattern: "[^0-9a-fA-F]", options: .caseInsensitive)
                if regex.numberOfMatches(in: deviceToken, options: [], range: NSRange(location: 0, length: deviceToken.count)) != 0 {
                    AirshipLogger.error("Device token \(deviceToken) contains invalid characters. Only hex characters are allowed")
                    return
                }

                if deviceToken.count < 64 || deviceToken.count > 200 {
                    AirshipLogger.warn("Device token \(deviceToken) should be 64 to 200 hex characters (32 to 100 bytes) long.")
                }

                self.willChangeValue(forKey: "deviceToken")
                self.dataStore.setObject(deviceToken, forKey: Push.DeviceTokenKey);
                self.deviceTokenAvailableBlock?()
                self.didChangeValue(forKey: "deviceToken");
                AirshipLogger.importantInfo("Device token: \(deviceToken)")
            } catch {
                AirshipLogger.error("Unable to set device token")
            }
        }

        get {
            return self.dataStore.string(forKey: Push.DeviceTokenKey)
        }
    }

    /// User Notification options this app will request from APNS. Changes to this value
    /// will not take effect until the next time the app registers with
    /// updateRegistration.
    ///
    /// Defaults to alert, sound and badge.
    @objc
    public var notificationOptions: UANotificationOptions {
        set {
            self.dataStore.setObject(NSNumber(value:newValue.rawValue), forKey: Push.PushNotificationsOptionsKey)
            self.shouldUpdateAPNSRegistration = true
        }

        get {
            guard let value = self.dataStore.object(forKey: Push.PushNotificationsOptionsKey) as? NSNumber else {
                #if os(tvOS)
                return .badge
                #else
                return [.badge, .sound, .alert]
                #endif
            }

            return UANotificationOptions(rawValue: value.uintValue)
        }
    }

    #if !os(tvOS)
    /// Custom notification categories. Airship default notification
    /// categories will be unaffected by this field.
    ///
    /// Changes to this value will not take effect until the next time the app registers
    /// with updateRegistration.
    @objc
    public var customCategories: Set<UNNotificationCategory> {
        set {
            _customCategories = newValue.filter({ category in
                if category.identifier.hasPrefix("ua_") {
                    AirshipLogger.warn("Ignoring category \(category.identifier), only Airship notification categories are allowed to have prefix ua_.")
                    return false
                }

                return true
            })

            self.shouldUpdateAPNSRegistration = true
        }

        get {
            return _customCategories
        }
    }

    /// The combined set of notification categories from `customCategories` set by the app
    /// and the Airship provided categories.
    @objc
    public var combinedCategories: Set<UNNotificationCategory> {
        get {
            let defaultCategories = UANotificationCategories.defaultCategories(withRequireAuth: requireAuthorizationForDefaultCategories)
            return defaultCategories.union(self.customCategories.union(self.accengageCategories))
        }
    }

    /// The set of Accengage notification categories.
    /// - Note For internal use only. :nodoc:
    @objc
    public var accengageCategories: Set<UNNotificationCategory> = [] {
        didSet {
            self.shouldUpdateAPNSRegistration = true
        }
    }
#endif

    /// Sets authorization required for the default Airship categories. Only applies
    /// to background user notification actions.
    ///
    /// Changes to this value will not take effect until the next time the app registers
    /// with updateRegistration.
    @objc
    public var requireAuthorizationForDefaultCategories = false {
        didSet {
            self.shouldUpdateAPNSRegistration = true
        }
    }
    
    /// Set a delegate that implements the PushNotificationDelegate protocol.
    @objc
    public weak var pushNotificationDelegate: PushNotificationDelegate?

    /// Set a delegate that implements the UARegistrationDelegate protocol.
    @objc
    public weak var registrationDelegate: RegistrationDelegate?

    #if !os(tvOS)
    /// Notification response that launched the application.
    @objc
    public private(set) var launchNotificationResponse: UNNotificationResponse?
    #endif
    /// The current authorized notification settings.
    /// If push is disabled in privacy manager, this value could be out of date.
    ///
    /// Note: this value reflects all the notification settings currently enabled in the
    /// Settings app and does not take into account which options were originally requested.
    @objc
    public private(set) var authorizedNotificationSettings: UAAuthorizedNotificationSettings {
        set {
            if !self.dataStore.keyExists(Push.TypesAuthorizedKey) || self.dataStore.integer(forKey: Push.TypesAuthorizedKey) != newValue.rawValue {
                self.dataStore.setInteger(Int(newValue.rawValue), forKey: Push.TypesAuthorizedKey)
                self.updateRegistration()
                
                self.registrationDelegate?.notificationAuthorizedSettingsDidChange?(newValue)
            }
        }

        get {
            guard let value = self.dataStore.object(forKey: Push.TypesAuthorizedKey) as? NSNumber else {
                return []
            }

            return UAAuthorizedNotificationSettings(rawValue: value.uintValue)
        }
    }

    /// The current authorization status.
    /// If push is disabled in privacy manager, this value could be out of date.
    @objc
    public private(set) var authorizationStatus: UAAuthorizationStatus {
        set {
            let previous = self.authorizationStatus
            if newValue != previous {
                self.dataStore.setInteger(newValue.rawValue, forKey: Push.AuthorizationStatusKey)
            }
        }

        get {
            guard let value = self.dataStore.object(forKey: Push.AuthorizationStatusKey) as? NSNumber else {
                return .notDetermined
            }

            return UAAuthorizationStatus(rawValue: Int(value.uintValue)) ?? .notDetermined
        }
    }

    /// Indicates whether the user has been prompted for notifications or not.
    /// If push is disabled in privacy manager, this value will be out of date.
    @objc
    public private(set) var userPromptedForNotifications: Bool {
        set {
            let previous = self.dataStore.bool(forKey: Push.UserPromptedForNotificationsKey)
            if previous != newValue {
                self.dataStore.setBool(newValue, forKey: Push.UserPromptedForNotificationsKey)
            }
        }

        get {
            return self.dataStore.bool(forKey: Push.UserPromptedForNotificationsKey)
        }
    }

    /// The default presentation options to use for foreground notifications.
    @objc
    public var defaultPresentationOptions: UNNotificationPresentationOptions

    /// Syncs locally stored authorized notifaction types with push registration, and performs a new channel
    /// registration as needed.
    ///
    /// For internal use only. :nodoc:
    @objc
    public func updateAuthorizedNotificationTypes() {
        guard self.privacyManager.isEnabled(.push) else {
            return
        }

        self.pushRegistration.getAuthorizedSettings(completionHandler: { authorizedSettings, status in
            guard self.privacyManager.isEnabled(.push) else {
                return
            }

            if self.userPromptedForNotifications || authorizedSettings != [] {
                self.userPromptedForNotifications = true
                self.authorizedNotificationSettings = authorizedSettings
            }

            self.authorizationStatus = status

            if !self.config.requestAuthorizationToUseNotifications {
                // if app is managing notification authorization update channel
                // registration in case notification authorization has changed
                self.channel.updateRegistration()
            }
        })
    }

    /// Enables user notifications on this device through Airship.
    ///
    /// - Note: The completion handler will return the success state of system push authorization as it is defined by the
    /// user's response to the push authorization prompt. The completion handler success state does NOT represent the
    /// state of the userPushNotificationsEnabled flag, which will be invariably set to `true` after the completion of this call.
    ///
    /// - Parameter completionHandler: The completion handler with success flag representing the system authorization state.
    @objc
    public func enableUserPushNotifications(_ completionHandler: @escaping (_ success: Bool) -> Void) {
        self.dataStore.setBool(true, forKey: Push.UserPushNotificationsEnabledKey)
        self.updateAPNSRegistration { success in
            self.channel.updateRegistration()
            completionHandler(success)
        }
    }

    private func waitForDeviceTokenRegistration(_ completionHandler: @escaping () -> Void) {
        self.dispatcher.dispatchAsync { [weak self] in
            guard let self = self else {
                return
            }

            if self.waitForDeviceToken && self.privacyManager.isEnabled(.push) && self.deviceToken == nil && self.application.isRegisteredForRemoteNotifications {
                let semaphore = UASemaphore()
                self.waitForDeviceToken = false

                self.deviceTokenAvailableBlock = {
                    semaphore.signal()
                }

                UADispatcher.global.dispatchAsync { [weak self] in
                    guard let self = self else {
                        return
                    }

                    semaphore.wait(Push.DeviceTokenRegistrationWaitTime)
                    self.dispatcher.dispatchAsync(completionHandler)
                }

            } else {
                completionHandler()
            }
        }
    }

    private func userPushNotificationsAllowed() -> Bool {
        var allowed = true

        if self.deviceToken == nil {
            AirshipLogger.trace("Opted out: missing device token")
            allowed = false
        }

        if !self.userPushNotificationsEnabled {
            AirshipLogger.trace("Opted out: user push notifications disabled");
            allowed = false;
        }

        if self.authorizedNotificationSettings == [] {
            AirshipLogger.trace("Opted out: no authorized notification settings")
            allowed = false;
        }

        if !self.isRegisteredForRemoteNotifications {
            AirshipLogger.trace("Opted out: not registered for remote notifications")
            allowed = false;
        }

        if !self.privacyManager.isEnabled(.push) {
            AirshipLogger.trace("Opted out: push is disabled");
            allowed = false;
        }

        return allowed;
    }

    private func backgroundPushNotificationsAllowed() -> Bool {
        guard self.deviceToken != nil &&
                self.backgroundPushNotificationsEnabled &&
                UAirship.shared().remoteNotificationBackgroundModeEnabled &&
                self.privacyManager.isEnabled(.push) else {
            return false
        }

        return self.isRegisteredForRemoteNotifications && self.isBackgroundRefreshStatusAvailable
    }

    private func updatePushEnablement() {
        if self.isComponentEnabled && self.privacyManager.isEnabled(.push) {
            if !self.pushEnabled {
                self.application.registerForRemoteNotifications()
                self.shouldUpdateAPNSRegistration = true
                self.updateAuthorizedNotificationTypes()
                self.updateRegistration()
                self.pushEnabled = true
            }
        } else {
            self.pushEnabled = false
        }
    }

    /// Updates the registration with APNS. Call after modifying notification types
    /// and user notification categories.
    private func updateAPNSRegistration(_ completionHandler: @escaping (_ success: Bool) -> Void) {
        guard self.privacyManager.isEnabled(.push) else {
            return
        }

        self.shouldUpdateAPNSRegistration = false

        self.pushRegistration.getAuthorizedSettings(completionHandler: { authorizedSettings, status in
            var options: UANotificationOptions = []

            #if !os(tvOS)
            var categories: Set<UNNotificationCategory> = []
            #endif

            if self.userPushNotificationsEnabled {
                options = self.notificationOptions
                #if !os(tvOS)
                categories = self.combinedCategories
                #endif
            }

            if !self.config.requestAuthorizationToUseNotifications {
                // The app is handling notification authorization
                self.notificationRegistrationFinished(authorizedSettings: authorizedSettings, status:status)
                completionHandler(true)
            } else if (authorizedSettings == [] && options == []) {
                completionHandler(false)
            } else if (status == .ephemeral && !self.extendedPushNotificationPermissionEnabled) {
                self.notificationRegistrationFinished(authorizedSettings: authorizedSettings, status:status)
                completionHandler(true)
            } else {
                #if !os(tvOS)
                self.pushRegistration.updateRegistration(options: options, categories: categories) { result, authorizedSettings, status in
                    self.notificationRegistrationFinished(authorizedSettings: authorizedSettings, status:status)
                    completionHandler(result)
                }
                #else
                self.pushRegistration.updateRegistration(options: options) { result, authorizedSettings, status in
                    self.notificationRegistrationFinished(authorizedSettings: authorizedSettings, status:status)
                    completionHandler(result)
                }
                #endif
            }
        })
    }

    private func notificationRegistrationFinished(authorizedSettings: UAAuthorizedNotificationSettings, status: UAAuthorizationStatus) {
        guard self.privacyManager.isEnabled(.push) else {
            return
        }

        if self.deviceToken == nil {
            self.dispatcher.dispatchAsync { [weak self] in
                self?.application.registerForRemoteNotifications()
            }
        }

        self.userPromptedForNotifications = true;
        self.authorizedNotificationSettings = authorizedSettings;
        self.authorizationStatus = status;

        UADispatcher.main.dispatchAsync {
            #if !os(tvOS)
            self.registrationDelegate?.notificationRegistrationFinished?(withAuthorizedSettings: authorizedSettings, categories: self.combinedCategories, status: status)

            #else
            self.registrationDelegate?.notificationRegistrationFinished?(withAuthorizedSettings: authorizedSettings, status: status)
            #endif
        }
    }

    // MARK: - Badging

    /// The current badge number used by the device and on the Airship server.
    ///
    /// - Note: This property must be accessed on the main thread.
    @objc
    public var badgeNumber: Int {
        set {
            let application = self.application

            if application.applicationIconBadgeNumber == newValue {
                return
            }

            AirshipLogger.debug("Change Badge from \(application.applicationIconBadgeNumber), to \(newValue)")

            application.applicationIconBadgeNumber = newValue

            // if the device token has already been set then
            // we are post-registration and will need to make
            // an update call
            if self.autobadgeEnabled && (self.deviceToken != nil || self.channel.identifier != nil) {
                AirshipLogger.debug("Sending autobadge update to Airship server.")
                self.channel.updateRegistration(forcefully: true)
            }
        }

        get {
            return self.application.applicationIconBadgeNumber
        }
    }
    
    /// Toggle the Airship auto-badge feature. Defaults to `false` If enabled, this will update the
    /// badge number stored by Airship every time the app is started or foregrounded.
    @objc
    public var autobadgeEnabled: Bool {
        set {
            self.dataStore.setBool(newValue, forKey: Push.BadgeSettingsKey)
        }

        get {
            return self.dataStore.bool(forKey:Push.BadgeSettingsKey)
        }
    }

    /// Resets the badge to zero (0) on both the device and on Airships servers. This is a
    /// convenience method for setting the `badgeNumber` property to zero.
    ///
    /// - Note: This method must be called on the main thread.
    @objc
    public func resetBadge() {
        self.badgeNumber = 0
    }

    // MARK: - Quiet Time

    /// Quiet time settings for this device.
    @objc
    public private(set) var quietTime: [AnyHashable : Any]? {
        set {
            self.dataStore.setObject(newValue, forKey: Push.QuietTimeSettingsKey)
        }

        get {
            return self.dataStore.dictionary(forKey: Push.QuietTimeSettingsKey)
        }
    }

    /// Time Zone for quiet time. If the time zone is not set, the current
    /// local time zone is returned.
    @objc
    public var timeZone: NSTimeZone? {
        set {
            self.dataStore.setObject(newValue?.name ?? nil, forKey: Push.TimeZoneSettingsKey)
        }

        get {
            let timeZoneName = self.dataStore.string(forKey: Push.TimeZoneSettingsKey) ?? ""
            return NSTimeZone(name: timeZoneName) ?? NSTimeZone.default as NSTimeZone
        }
    }

    /// Enables/Disables quiet time
    @objc
    public var quietTimeEnabled: Bool {
        set {
            self.dataStore.setBool(newValue, forKey: Push.QuietTimeEnabledSettingsKey)
        }

        get {
            return self.dataStore.bool(forKey: Push.QuietTimeEnabledSettingsKey)
        }
    }

    /// Sets the quiet time start and end time.  The start and end time does not change
    /// if the time zone changes.  To set the time zone, see 'timeZone'.
    ///
    /// Update the server after making changes to the quiet time with the
    /// `updateRegistration` call. Batching these calls improves API and client performance.
    ///
    /// - Warning: This method does not automatically enable quiet time and does not
    /// automatically update the server. Please refer to `quietTimeEnabled` and
    /// `updateRegistration` for more information.
    ///
    /// - Parameters:
    ///   - startHour: Quiet time start hour. Only 0-23 is valid.
    ///   - startMinute: Quiet time start minute. Only 0-59 is valid.
    ///   - endHour: Quiet time end hour. Only 0-23 is valid.
    ///   - endMinute: Quiet time end minute. Only 0-59 is valid.

    @objc
    public func setQuietTimeStartHour(
        _ startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int
    ) {
        let startTimeString = "\(String(format: "%02d", startHour)):\(String(format: "%02d", startMinute))"
        let endTimeString = "\(String(format: "%02d", endHour)):\(String(format: "%02d", endMinute))"

        if startHour >= 24 || startMinute >= 60 {
            AirshipLogger.error("Unable to set quiet time, invalid start time: \(startTimeString)")
            return;
        }

        if endHour >= 24 || endMinute >= 60 {
            AirshipLogger.error("Unable to set quiet time, invalid end time: \(endTimeString)")
            return;
        }

        AirshipLogger.debug("Setting quiet time: \(startTimeString) to \(endTimeString)")

        self.quietTime = [Push.QuietTimeStartKey : startTimeString,
                          Push.QuietTimeEndKey : endTimeString];
    }

    // MARK: - Registration

    /// Registers or updates the current registration with an API call. If push notifications are
    /// not enabled, this unregisters the device token.
    ///
    /// Add a `UARegistrationDelegate` to `UAPush` to receive success and failure callbacks.
    @objc
    public func updateRegistration() {
        if !self.privacyManager.isEnabled(UAFeatures.push) {
            return
        }

        if self.shouldUpdateAPNSRegistration {
            AirshipLogger.debug("APNS registration is out of date, updating.")
            self.updateAPNSRegistration { [weak self] _ in
                self?.channel.updateRegistration()
            }
        } else {
            self.channel.updateRegistration()
        }
    }

    // MARK: - FeatureEnablement

    // For internal use only. :nodoc:
    @objc
    public override func onComponentEnableChange() {
        self.updatePushEnablement()
    }

    @objc
    private func onEnabledFeaturesChanged() {
        self.updatePushEnablement()
    }

    // MARK: - App Integration

    /// Called by the UIApplicationDelegate's application:didRegisterForRemoteNotificationsWithDeviceToken:
    /// so UAPush can forward the delegate call to its registration delegate.
    ///
    /// For internal use only. :nodoc:
    ///
    /// - Parameters:
    ///   - application: The application instance.
    ///   - deviceToken: The APNS device token.
    @objc
    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        guard self.privacyManager.isEnabled(.push) else {
            return
        }

        self.deviceToken = UAUtils.deviceTokenStringFromDeviceToken(deviceToken)

        if self.appStateTracker.state == .background && self.channel.identifier != nil {
            AirshipLogger.debug("Skipping channel registration. The app is currently backgrounded and we already have a channel ID.")
        } else {
            self.channel.updateRegistration()
        }

        self.registrationDelegate?.apnsRegistrationSucceeded?(withDeviceToken: deviceToken)
    }

    /// Called by the UIApplicationDelegate's application:didFailToRegisterForRemoteNotificationsWithError:
    /// so UAPush can forward the delegate call to its registration delegate.
    ///
    /// For internal use only. :nodoc:
    ///
    /// - Parameters:
    ///   - application: The application instance.
    ///   - error: An NSError object that encapsulates information why registration did not succeed.
    @objc
    public func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        guard self.privacyManager.isEnabled(.push) else {
            return
        }

        self.registrationDelegate?.apnsRegistrationFailedWithError?(error)
    }


    /// Called to return the presentation options for a notification.
    ///
    /// For internal use only. :nodoc:
    ///
    /// - Parameter notification: The notification.
    /// - Returns: Foreground presentation options.
    @objc
    public func presentationOptionsForNotification(_ notification: UNNotification) -> UNNotificationPresentationOptions {
        guard self.privacyManager.isEnabled(.push) else {
            return []
        }

        var options: UNNotificationPresentationOptions = [];

        //Get foreground presentation options defined from the push API/dashboard
        if let payloadPresentationOptions = self.foregroundPresentationOptions(notification:notification) {
            if payloadPresentationOptions.count > 0 {
                // build the options bitmask from the array
                for presentationOption in payloadPresentationOptions {
                    switch presentationOption {
                    case Push.PresentationOptionBadge:
                        options.insert(.badge)
                    case Push.PresentationOptionAlert:
                        options.insert(.alert)
                    case Push.PresentationOptionSound:
                        options.insert(.sound)
                    #if !targetEnvironment(macCatalyst)
                    case Push.PresentationOptionList:
                        if #available(iOS 14.0, tvOS 14.0, *) {
                            options.insert(.list)
                        }
                    case Push.PresentationOptionBanner:
                        if #available(iOS 14.0, tvOS 14.0, *) {
                            options.insert(.banner)
                        } else {
                            // Fallback on earlier versions
                        }
                    #endif
                    default:
                        break
                    }
                }
            } else {
                options = self.defaultPresentationOptions;
            }
        } else {
            options = self.defaultPresentationOptions
        }

        if let extendedOptions = self.pushNotificationDelegate?.extend?(options, notification: notification) {
            options = extendedOptions
        }

        return options;
    }

    #if !os(tvOS)
    /// Called when a notification response is received.
    ///
    /// For internal use only. :nodoc:
    ///
    /// - Parameters:
    ///   - response: The notification response.
    ///   - handler: The completion handler.
    @objc
    public func handleNotificationResponse(_ response: UNNotificationResponse, completionHandler handler: @escaping () -> Void) {
        guard self.privacyManager.isEnabled(.push) else {
            handler();
            return;
        }

        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            self.launchNotificationResponse = response
        }

        self.notificationCenter.post(name: Push.ReceivedNotificationResponseEvent, object: self, userInfo:[Push.ReceivedNotificationResponseEventResponseKey : response]);

        if let callback = self.pushNotificationDelegate?.receivedNotificationResponse {
            callback(response, handler)
        } else {
            handler()
        }
    }
    #endif

    /// Called when a remote notification is received.
    ///
    /// For internal use only. :nodoc:
    ///
    /// - Parameters:
    ///   - notification: The notification content.
    ///   - foreground: If the notification was recieved in the foreground or not.
    ///   - handler: The completion handler.
    @objc
    public func handleRemoteNotification(_ notification: [AnyHashable : Any], foreground: Bool, completionHandler handler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard self.privacyManager.isEnabled(.push) else {
            handler(.noData);
            return;
        }

        let delegate = self.pushNotificationDelegate

        if (foreground) {
            if (self.autobadgeEnabled) {
                if let aps = notification["aps"] as? [AnyHashable : Any] {
                    if let badge = aps["badge"] as? Int {
                        self.application.applicationIconBadgeNumber = badge
                    }
                }
            }

            self.notificationCenter.post(name: Push.ReceivedForegroundNotificationEvent, object: self, userInfo: notification)

            if let callback = delegate?.receivedForegroundNotification {
                callback(notification, {
                    handler(.noData)
                });
            } else {
                handler(.noData)
            }
        } else {
            self.notificationCenter.post(name: Push.ReceivedBackgroundNotificationEvent, object: self, userInfo: notification)

            if let callback = delegate?.receivedBackgroundNotification {
                callback(notification, { result in
                    handler(result)
                })
            } else {
                handler(.noData)
            }
        }
    }

    private func foregroundPresentationOptions(notification: UNNotification) -> [String]? {
        var presentationOptions: [String]? = nil;
    #if !os(tvOS)   // UNNotificationContent.userInfo not available on tvOS
        // get the presentation options from the the notification
        presentationOptions = notification.request.content.userInfo[Push.ForegroundPresentationkey] as? [String]

        if (presentationOptions == nil) {
            presentationOptions = notification.request.content.userInfo[Push.ForegroundPresentationLegacykey] as? [String]
        }
    #endif
        return presentationOptions;
    }

    // MARK: - App lifecycle

    @objc
    private func applicationDidTransitionToForeground() {
        if self.privacyManager.isEnabled(.push) {
            self.updateAuthorizedNotificationTypes()
        }
    }

    @objc
    private func applicationDidEnterBackground() {
    #if !os(tvOS)
        self.launchNotificationResponse = nil
    #endif
        if self.privacyManager.isEnabled(.push) {
            AirshipLogger.trace("Application entered the background. Updating authorization.")
            self.updateAuthorizedNotificationTypes()
        }
    }

    @objc
    private func applicationBackgroundRefreshStatusChanged() {
        if self.privacyManager.isEnabled(.push) {
            AirshipLogger.trace("Background refresh status changed.")

            if self.application.backgroundRefreshStatus == .available {
                self.application.registerForRemoteNotifications()
            } else {
                self.channel.updateRegistration()
            }
        }
    }

    // MARK: - Extenders

    private func extendChannelRegistrationPayload(_ payload: ChannelRegistrationPayload, completionHandler: @escaping (ChannelRegistrationPayload) -> Void) {
        guard self.privacyManager.isEnabled(.push) else {
            completionHandler(payload)
            return
        }

        self.waitForDeviceTokenRegistration { [weak self] in
            guard let self = self else {
                return
            }
            
            guard self.privacyManager.isEnabled(.push) else {
                completionHandler(payload)
                return
            }
            
            payload.channel.pushAddress = self.deviceToken
            payload.channel.isOptedIn = self.userPushNotificationsAllowed()
            payload.channel.isBackgroundEnabled = self.backgroundPushNotificationsAllowed()

            if (self.autobadgeEnabled) {
                payload.channel.iOSChannelSettings = payload.channel.iOSChannelSettings ?? ChannelRegistrationPayload.iOSChannelSettings()
                
                payload.channel.iOSChannelSettings?.badge = self.badgeNumber
            }
            
            if let timeZoneName = self.timeZone?.name,
               let quietTimeStart = self.quietTime?[Push.QuietTimeStartKey] as? String,
               let quietTimeEnd = self.quietTime?[Push.QuietTimeEndKey] as? String,
               self.quietTimeEnabled {
                
                
                payload.channel.iOSChannelSettings = payload.channel.iOSChannelSettings ?? ChannelRegistrationPayload.iOSChannelSettings()
                
                let quietTime = ChannelRegistrationPayload.QuietTime(start: quietTimeStart, end: quietTimeEnd)
                payload.channel.iOSChannelSettings?.quietTimeTimeZone = timeZoneName
                payload.channel.iOSChannelSettings?.quietTime = quietTime
            }

            completionHandler(payload)
        };
    }

    private func analyticsHeaders() -> [String : String] {
        if self.privacyManager.isEnabled(.push) {
            var headers:[String : String] = [:]
            headers["X-UA-Channel-Opted-In"] = self.userPushNotificationsAllowed() ? "true" : "false"
            headers["X-UA-Notification-Prompted"] = self.userPromptedForNotifications ? "true" : "false"
            headers["X-UA-Channel-Background-Enabled"] = self.backgroundPushNotificationsAllowed() ? "true" : "false"
            headers["X-UA-Push-Address"] = self.deviceToken

            return headers
        } else {
            return ["X-UA-Channel-Opted-In" : "false", "X-UA-Channel-Background-Enabled" : "false"]
        }
    }
}
