/* Copyright Airship and Contributors */

import Foundation
import UserNotifications
#if os(watchOS)
import WatchKit
import UIKit
#endif

/// This singleton provides an interface to the functionality provided by the Airship iOS Push API.
@objc(UAPush)
public class Push: NSObject, Component, PushProtocol {
    
    /// The shared Push instance.
    @objc
    public static var shared: Push {
        return Airship.push
    }

    /// NSNotification event when a notification response is received.
    /// The event will contain the notification response object.
    @objc
    public static let receivedNotificationResponseEvent = NSNotification.Name("com.urbanairship.push.received_notification_response")

    /// Response key for ReceivedNotificationResponseEvent
    @objc
    public static let receivedNotificationResponseEventResponseKey = "response"

    /// NSNotification event when a foreground notification is received.
    /// The event will contain the payload dictionary as user info.
    @objc
    public static let receivedForegroundNotificationEvent = NSNotification.Name("com.urbanairship.push.received_foreground_notification")

    /// NSNotification event when a background notification is received.
    /// The event will contain the payload dictionary as user info.
    @objc
    public static let receivedBackgroundNotificationEvent = NSNotification.Name("com.urbanairship.push.received_background_notification")

    /// Quiet Time dictionary start key. For internal use only :nodoc:
    @objc
    public static let quietTimeStartKey = "start"

    /// Quiet Time dictionary end key. For internal use only :nodoc:
    @objc
    public static let quietTimeEndKey = "end"

    private static let pushNotificationsOptionsKey = "UAUserPushNotificationsOptions"
    private static let userPushNotificationsEnabledKey = "UAUserPushNotificationsEnabled"
    private static let backgroundPushNotificationsEnabledKey = "UABackgroundPushNotificationsEnabled"
    private static let requestExplicitPermissionWhenEphemeralKey = "UAExtendedPushNotificationPermissionEnabled"

    private static let badgeSettingsKey = "UAPushBadge"
    private static let deviceTokenKey = "UADeviceToken"
    private static let quietTimeSettingsKey = "UAPushQuietTime"
    private static let quietTimeEnabledSettingsKey = "UAPushQuietTimeEnabled"
    private static let timeZoneSettingsKey = "UAPushTimeZone"

    private static let typesAuthorizedKey = "UAPushTypesAuthorized"
    private static let authorizationStatusKey = "UAPushAuthorizationStatus"
    private static let userPromptedForNotificationsKey = "UAPushUserPromptedForNotifications"

    // Old push enabled key
    private static let oldPushEnabledKey = "UAPushEnabled"
    
    // The default device tag group.
    private static let defaultDeviceTagGroup = "device"

    // The foreground presentation options that can be defined from API or dashboard
    private static let presentationOptionBadge = "badge"
    private static let presentationOptionAlert = "alert"
    private static let presentationOptionSound = "sound"
    private static let presentationOptionList = "list"
    private static let presentationOptionBanner = "banner"

    // Foreground presentation keys
    private static let ForegroundPresentationLegacykey = "foreground_presentation"
    private static let ForegroundPresentationkey = "com.urbanairship.foreground_presentation"
    private static let deviceTokenRegistrationWaitTime: TimeInterval = 10

    private let config: RuntimeConfig
    private let dataStore: PreferenceDataStore
    private let channel: ChannelProtocol
    private let privacyManager: PrivacyManager
    private let permissionsManager: PermissionsManager
    private let notificationCenter: NotificationCenter
    private let notificationRegistrar: NotificationRegistrar

    private let apnsRegistrar: APNSRegistrar
    private var badger: Badger

    private let mainDispatcher: UADispatcher
    private let disableHelper: ComponentDisableHelper
    private var shouldUpdateNotificationRegistration = true
    private var waitForDeviceToken = false
    private var pushEnabled = false
    private var deviceTokenAvailableBlock: (() -> Void)?

    private var isNotificationRegistrationDispatched = Atomic<Bool>(false)

    private var isRegisteredForRemoteNotifications: Bool {
        get {
            var registered = false
            self.mainDispatcher.doSync {
                registered = self.apnsRegistrar.isRegisteredForRemoteNotifications
            }
            return registered
        }
    }

    private var isBackgroundRefreshStatusAvailable: Bool {
        get {
            var available = false
#if !os(watchOS)
            self.mainDispatcher.doSync {
                available = self.apnsRegistrar.isBackgroundRefreshStatusAvailable
            }
#endif
            return available
        }
    }
    // NOTE: For internal use only. :nodoc:
    public var isComponentEnabled: Bool {
        get {
            return self.disableHelper.enabled
        }
        set {
            self.disableHelper.enabled = newValue
        }
    }
    
    init(config: RuntimeConfig,
         dataStore: PreferenceDataStore,
         channel:  ChannelProtocol,
         analytics: AnalyticsProtocol,
         privacyManager: PrivacyManager,
         permissionsManager: PermissionsManager,
         notificationCenter: NotificationCenter = NotificationCenter.default,
         notificationRegistrar: NotificationRegistrar = UNNotificationRegistrar(),
         apnsRegistrar: APNSRegistrar,
         badger: Badger,
         mainDispatcher: UADispatcher = UADispatcher.main) {

        self.config = config
        self.dataStore = dataStore
        self.channel = channel
        self.privacyManager = privacyManager
        self.permissionsManager = permissionsManager
        self.notificationCenter = notificationCenter
        self.notificationRegistrar = notificationRegistrar
        self.apnsRegistrar = apnsRegistrar
        self.badger = badger

        self.mainDispatcher = mainDispatcher
        self.disableHelper = ComponentDisableHelper(dataStore: dataStore,
                                                    className: "UAPush")
        super.init()
        
        self.disableHelper.onChange = { [weak self] in
            self?.onComponentEnableChange()
        }

        if (config.requestAuthorizationToUseNotifications) {
            let permissionDelegate = NotificationPermissionDelegate(registrar: self.notificationRegistrar) {
                let options = self.notificationOptions
                let skipIfEphemeral = !self.requestExplicitPermissionWhenEphemeral
                return NotificationPermissionDelegate.Config(options: options,
                                                             skipIfEphemeral: skipIfEphemeral)
            }

            self.permissionsManager.setDelegate(permissionDelegate, permission: .displayNotifications)
        }

        self.permissionsManager.addRequestExtender(permission: .displayNotifications) { status, completionHandler in
            self.onNotificationRegistrationFinished(completionHandler: completionHandler)
        }

        self.permissionsManager.addAirshipEnabler(permission: .displayNotifications) {
            self.dataStore.setBool(true, forKey: Push.userPushNotificationsEnabledKey)
            self.privacyManager.enableFeatures(.push)
            self.channel.updateRegistration()
        }

        self.waitForDeviceToken = self.channel.identifier == nil
        self.observeNotificationCenterEvents()

        var checkedAppRestore = false
        self.channel.addRegistrationExtender { payload, completionHandler in
            if (!checkedAppRestore && self.dataStore.isAppRestore) {
                self.resetDeviceToken()
            }
            checkedAppRestore = true
            self.extendChannelRegistrationPayload(payload, completionHandler: completionHandler)
        }

        analytics.add {
            return self.analyticsHeaders()
        }

        self.updatePushEnablement()
    
        if (!self.apnsRegistrar.isRemoteNotificationBackgroundModeEnabled) {
            AirshipLogger.impError("Application is not configured for background notifications. Please enable remote notifications in the application's background modes.")
        }
    }
    
    private func observeNotificationCenterEvents() {
#if !os(watchOS)
        self.notificationCenter.addObserver(self,
                                            selector: #selector(applicationBackgroundRefreshStatusChanged),
                                            name: UIApplication.backgroundRefreshStatusDidChangeNotification,
                                            object: nil)
#endif
        self.notificationCenter.addObserver(self,
                                            selector: #selector(applicationDidTransitionToForeground),
                                            name: AppStateTracker.didTransitionToForeground,
                                            object: nil)

        self.notificationCenter.addObserver(self,
                                            selector: #selector(applicationDidEnterBackground),
                                            name: AppStateTracker.didEnterBackgroundNotification,
                                            object: nil)

        self.notificationCenter.addObserver(self,
                                            selector: #selector(onEnabledFeaturesChanged),
                                            name: PrivacyManager.changeEvent,
                                            object: nil)
    }
    

    /// Enables/disables background remote notifications on this device through Airship.
    /// Defaults to `true`.
    @objc
    public var backgroundPushNotificationsEnabled: Bool {
        set {
            let previous = self.backgroundPushNotificationsEnabled
            self.dataStore.setBool(newValue, forKey: Push.backgroundPushNotificationsEnabledKey)
            if !previous == newValue {
                self.channel.updateRegistration()
            }
        }
        get {
            return self.dataStore.bool(forKey: Push.backgroundPushNotificationsEnabledKey, defaultValue: true)
        }
    }

    /// Enables/disables user notifications on this device through Airship.
    /// Defaults to `false`. Once set to `true`, the user will be prompted for remote notifications.
    @objc
    public var userPushNotificationsEnabled: Bool {
        set {
            let previous = self.userPushNotificationsEnabled
            self.dataStore.setBool(newValue, forKey: Push.userPushNotificationsEnabledKey)
            if previous != newValue {
                self.dispatchUpdateNotifications()
            }
        }

        get {
            return self.dataStore.bool(forKey: Push.userPushNotificationsEnabledKey)
        }
    }

    /// Enables/disables extended App Clip user notifications on this device through Airship.
    /// Defaults to `false`. Once set to `true`, the user will be prompted for remote notifications if userPushNotificationsEnabled and the user currently has
    /// ephemeral authorization.
    @objc
    @available(*, deprecated, message: "Use requestExplicitPermissionWhenEphemeral instead")
    public var extendedPushNotificationPermissionEnabled: Bool {
        set {
            self.requestExplicitPermissionWhenEphemeral = newValue
        }
        get {
            self.requestExplicitPermissionWhenEphemeral
        }
    }

    /// When enabled, if the user has ephemeral notification authorization the SDK will promp the user for
    /// notifications.  Defaults to `false`.
    @objc
    public var requestExplicitPermissionWhenEphemeral: Bool {
        set {
            let previous = self.requestExplicitPermissionWhenEphemeral
            if previous != newValue {
                self.dataStore.setBool(newValue, forKey: Push.requestExplicitPermissionWhenEphemeralKey)
                self.dispatchUpdateNotifications()
            }
        }
        get {
            return self.dataStore.bool(forKey: Push.requestExplicitPermissionWhenEphemeralKey)
        }
    }

    /// The device token for this device, as a hex string.
    @objc
    public private(set) var deviceToken: String? {
        set {
            guard let deviceToken = newValue else {
                self.dataStore.removeObject(forKey: Push.deviceTokenKey)
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

                self.dataStore.setObject(deviceToken, forKey: Push.deviceTokenKey)
                self.deviceTokenAvailableBlock?()
                AirshipLogger.importantInfo("Device token: \(deviceToken)")
            } catch {
                AirshipLogger.error("Unable to set device token")
            }
        }

        get {
            return self.dataStore.string(forKey: Push.deviceTokenKey)
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
            let previous = self.notificationOptions
            self.dataStore.setObject(NSNumber(value:newValue.rawValue), forKey: Push.pushNotificationsOptionsKey)
            if previous != newValue {
                self.dispatchUpdateNotifications()
            }
        }

        get {
            guard let value = self.dataStore.object(forKey: Push.pushNotificationsOptionsKey) as? NSNumber else {
#if os(tvOS)
                return .badge
#else
                if (self.authorizationStatus == .provisional) {
                    return [.badge, .sound, .alert, .provisional]
                } else {
                    return [.badge, .sound, .alert]
                }
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
    public var customCategories: Set<UNNotificationCategory> = Set() {
        didSet {
            self.updateCategories()
        }
    }

    /// The combined set of notification categories from `customCategories` set by the app
    /// and the Airship provided categories.
    @objc
    public var combinedCategories: Set<UNNotificationCategory> {
        get {
            let defaultCategories = NotificationCategories.defaultCategories(withRequireAuth: requireAuthorizationForDefaultCategories)
            return defaultCategories.union(self.customCategories.union(self.accengageCategories))
        }
    }

    /// The set of Accengage notification categories.
    /// - Note For internal use only. :nodoc:
    @objc
    public var accengageCategories: Set<UNNotificationCategory> = [] {
        didSet {
            self.updateCategories()
        }
    }
#endif

    /// Sets authorization required for the default Airship categories. Only applies
    /// to background user notification actions.
    ///
    /// Changes to this value will not take effect until the next time the app registers
    /// with updateRegistration.
    @objc
    public var requireAuthorizationForDefaultCategories = true {
        didSet {
            self.updateCategories()
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
            self.dataStore.setInteger(Int(newValue.rawValue), forKey: Push.typesAuthorizedKey)
        }

        get {
            guard let value = self.dataStore.object(forKey: Push.typesAuthorizedKey) as? NSNumber else {
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
            self.dataStore.setInteger(newValue.rawValue, forKey: Push.authorizationStatusKey)
        }

        get {
            guard let value = self.dataStore.object(forKey: Push.authorizationStatusKey) as? NSNumber else {
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
            self.dataStore.setBool(newValue, forKey: Push.userPromptedForNotificationsKey)
        }
        get {
            return self.dataStore.bool(forKey: Push.userPromptedForNotificationsKey)
        }
    }

    /// The default presentation options to use for foreground notifications.
    @objc
    public var defaultPresentationOptions: UNNotificationPresentationOptions = []


    func updateAuthorizedNotificationTypes() {
        self.updateAuthorizedNotificationTypes { settingsChanged, _, _ in
            if (settingsChanged) {
                self.channel.updateRegistration()
            }
        }
    }


    private func updateAuthorizedNotificationTypes(completionHandler: @escaping (Bool, UAAuthorizationStatus, UAAuthorizedNotificationSettings) -> Void) {

        AirshipLogger.trace("Updating authorized types.")

        self.notificationRegistrar.checkStatus { status, settings in
            var settingsChanged = false
            if self.privacyManager.isEnabled(.push) {

                if (!self.userPromptedForNotifications) {
                    if (status != .notDetermined && status != .ephemeral) {
                        self.userPromptedForNotifications = true
                    }
                }

                if (status != self.authorizationStatus) {
                    self.authorizationStatus = status
                    settingsChanged = true
                }

                if (self.authorizedNotificationSettings != settings) {
                    self.authorizedNotificationSettings = settings
                    self.mainDispatcher.dispatchAsync {
                        self.registrationDelegate?.notificationAuthorizedSettingsDidChange?(settings)
                    }
                    settingsChanged = true
                }
            }

            completionHandler(settingsChanged, status, settings)
        }
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
        self.dataStore.setBool(true, forKey: Push.userPushNotificationsEnabledKey)
        self.permissionsManager.requestPermission(.displayNotifications) { status in
            completionHandler(status == .granted)
        }
    }

    private func waitForDeviceTokenRegistration(_ completionHandler: @escaping () -> Void) {
        self.mainDispatcher.dispatchAsync { [weak self] in
            guard let self = self else {
                return
            }

            if self.waitForDeviceToken && self.privacyManager.isEnabled(.push) && self.deviceToken == nil && self.apnsRegistrar.isRegisteredForRemoteNotifications {
                let semaphore = Semaphore()
                self.waitForDeviceToken = false

                self.deviceTokenAvailableBlock = {
                    semaphore.signal()
                }

                UADispatcher.globalDispatcher(.utility).dispatchAsync { [weak self] in
                    guard let self = self else {
                        return
                    }

                    semaphore.wait(Push.deviceTokenRegistrationWaitTime)
                    self.mainDispatcher.dispatchAsync(completionHandler)
                }
            } else {
                completionHandler()
            }
        }
    }

    /// Indicates whether the user is opted in for push notifications or not.
    @objc
    public var isPushNotificationsOptedIn: Bool {
        get {
            var optedIn = true

            if self.deviceToken == nil {
                AirshipLogger.trace("Opted out: missing device token")
                optedIn = false
            }

            if !self.userPushNotificationsEnabled {
                AirshipLogger.trace("Opted out: user push notifications disabled")
                optedIn = false
            }

            if self.authorizedNotificationSettings == [] {
                AirshipLogger.trace("Opted out: no authorized notification settings")
                optedIn = false
            }

            if !self.isRegisteredForRemoteNotifications {
                AirshipLogger.trace("Opted out: not registered for remote notifications")
                optedIn = false
            }

            if !self.privacyManager.isEnabled(.push) {
                AirshipLogger.trace("Opted out: push is disabled")
                optedIn = false
            }

            return optedIn
        }
    }

    private func backgroundPushNotificationsAllowed() -> Bool {
        guard self.deviceToken != nil,
              self.backgroundPushNotificationsEnabled,
              self.apnsRegistrar.isRemoteNotificationBackgroundModeEnabled,
              self.privacyManager.isEnabled(.push)
        else {
            return false
        }

        return self.isRegisteredForRemoteNotifications && self.isBackgroundRefreshStatusAvailable
    }

    private func updatePushEnablement() {
        if self.isComponentEnabled && self.privacyManager.isEnabled(.push) {
            if !self.pushEnabled {
                self.pushEnabled = true
                self.apnsRegistrar.registerForRemoteNotifications()
                self.dispatchUpdateNotifications()
                self.updateCategories()
            }
        } else {
            self.pushEnabled = false
        }
    }

    private func onNotificationRegistrationFinished(completionHandler: (() -> Void)? = nil) {
        guard self.privacyManager.isEnabled(.push) else {
            completionHandler?()
            return
        }

        if self.deviceToken == nil {
            self.mainDispatcher.dispatchAsync { [weak self] in
                self?.apnsRegistrar.registerForRemoteNotifications()
            }
        }

        self.updateAuthorizedNotificationTypes { _, status, settings in
            self.mainDispatcher.dispatchAsync {
#if !os(tvOS)
                self.registrationDelegate?.notificationRegistrationFinished?(withAuthorizedSettings: settings,
                                                                             categories: self.combinedCategories,
                                                                             status: status)

#else
                self.registrationDelegate?.notificationRegistrationFinished?(withAuthorizedSettings: settings, status: status)
#endif
                self.channel.updateRegistration()
            }
            completionHandler?()
        }
    }

#if !os(watchOS)
    /// The current badge number used by the device and on the Airship server.
    ///
    /// - Note: This property must be accessed on the main thread.
    @objc
    public var badgeNumber: Int {
        set {
            if self.badger.applicationIconBadgeNumber == newValue {
                return
            }

            AirshipLogger.debug("Change Badge from \(self.badger.applicationIconBadgeNumber), to \(newValue)")

            self.badger.applicationIconBadgeNumber = newValue

            if (self.autobadgeEnabled) {
                self.channel.updateRegistration(forcefully: true)
            }
        }

        get {
            return self.badger.applicationIconBadgeNumber
        }
    }
    
    /// Toggle the Airship auto-badge feature. Defaults to `false` If enabled, this will update the
    /// badge number stored by Airship every time the app is started or foregrounded.
    @objc
    public var autobadgeEnabled: Bool {
        set {
            if self.autobadgeEnabled != newValue {
                self.dataStore.setBool(newValue, forKey: Push.badgeSettingsKey)
                self.channel.updateRegistration(forcefully: true)
            }
        }

        get {
            return self.dataStore.bool(forKey:Push.badgeSettingsKey)
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
    
#endif

    /// Quiet time settings for this device.
    @objc
    public private(set) var quietTime: [AnyHashable : Any]? {
        set {
            self.dataStore.setObject(newValue, forKey: Push.quietTimeSettingsKey)
            self.channel.updateRegistration()
        }

        get {
            return self.dataStore.dictionary(forKey: Push.quietTimeSettingsKey)
        }
    }

    /// Time Zone for quiet time. If the time zone is not set, the current
    /// local time zone is returned.
    @objc
    public var timeZone: NSTimeZone? {
        set {
            self.dataStore.setObject(newValue?.name ?? nil, forKey: Push.timeZoneSettingsKey)
        }

        get {
            let timeZoneName = self.dataStore.string(forKey: Push.timeZoneSettingsKey) ?? ""
            return NSTimeZone(name: timeZoneName) ?? NSTimeZone.default as NSTimeZone
        }
    }

    /// Enables/Disables quiet time
    @objc
    public var quietTimeEnabled: Bool {
        set {
            self.dataStore.setBool(newValue, forKey: Push.quietTimeEnabledSettingsKey)
        }

        get {
            return self.dataStore.bool(forKey: Push.quietTimeEnabledSettingsKey)
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
            return
        }

        if endHour >= 24 || endMinute >= 60 {
            AirshipLogger.error("Unable to set quiet time, invalid end time: \(endTimeString)")
            return
        }

        AirshipLogger.debug("Setting quiet time: \(startTimeString) to \(endTimeString)")

        self.quietTime = [Push.quietTimeStartKey : startTimeString,
                          Push.quietTimeEndKey : endTimeString]
    }

    /// Registers or updates the current registration with an API call. If push notifications are
    /// not enabled, this unregisters the device token.
    ///
    /// Add a `UARegistrationDelegate` to `UAPush` to receive success and failure callbacks.
    @objc
    public func updateRegistration() {
        self.dispatchUpdateNotifications()
    }

    private func updateCategories() {
#if !os(tvOS)
        guard self.isComponentEnabled,
              self.privacyManager.isEnabled(Features.push),
              self.config.requestAuthorizationToUseNotifications
        else {
            return
        }

        self.notificationRegistrar.setCategories(self.combinedCategories)
#endif
    }

    private func dispatchUpdateNotifications() {
        guard self.isNotificationRegistrationDispatched.compareAndSet(expected: false, value: true) else {
            return
        }

        mainDispatcher.dispatchAsync {
            self.isNotificationRegistrationDispatched.value = false

            guard self.isComponentEnabled, self.privacyManager.isEnabled(Features.push) else {
                return
            }

            guard self.config.requestAuthorizationToUseNotifications else {
                self.channel.updateRegistration()
                return
            }

            if (self.userPushNotificationsEnabled) {
                self.permissionsManager.requestPermission(.displayNotifications)
            } else {
                // If we are going from `ephemeral` to `[]` it will prompt the user to disable notifications...
                // avoid that by just skippping if we have ephemeral.
                self.notificationRegistrar.updateRegistration(options: [], skipIfEphemeral: true) {
                    self.onNotificationRegistrationFinished()
                }
            }
        }
    }


    /// - Note: For internal use only. :nodoc:
    private func onComponentEnableChange() {
        self.updatePushEnablement()
    }

    @objc
    private func onEnabledFeaturesChanged() {
        self.updatePushEnablement()
    }

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
            self.updateAuthorizedNotificationTypes()
        }
    }

#if !os(watchOS)
    @objc
    private func applicationBackgroundRefreshStatusChanged() {
        if self.privacyManager.isEnabled(.push) {
            AirshipLogger.trace("Background refresh status changed.")

            if self.apnsRegistrar.isBackgroundRefreshStatusAvailable {
                self.apnsRegistrar.registerForRemoteNotifications()
            } else {
                self.channel.updateRegistration()
            }
        }
    }
#endif

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
            payload.channel.isOptedIn = self.isPushNotificationsOptedIn
#if !os(watchOS)
            payload.channel.isBackgroundEnabled = self.backgroundPushNotificationsAllowed()
#endif
            
            payload.channel.iOSChannelSettings = payload.channel.iOSChannelSettings ?? ChannelRegistrationPayload.iOSChannelSettings()
            
#if !os(watchOS)
            if (self.autobadgeEnabled) {
                payload.channel.iOSChannelSettings?.badge = self.badgeNumber
            }
#endif
            
            if let timeZoneName = self.timeZone?.name,
               let quietTimeStart = self.quietTime?[Push.quietTimeStartKey] as? String,
               let quietTimeEnd = self.quietTime?[Push.quietTimeEndKey] as? String,
               self.quietTimeEnabled {
                
                let quietTime = ChannelRegistrationPayload.QuietTime(start: quietTimeStart, end: quietTimeEnd)
                payload.channel.iOSChannelSettings?.quietTimeTimeZone = timeZoneName
                payload.channel.iOSChannelSettings?.quietTime = quietTime
            }
            
            payload.channel.iOSChannelSettings?.isScheduledSummary = (self.authorizedNotificationSettings.rawValue & UAAuthorizedNotificationSettings.scheduledDelivery.rawValue > 0)
            payload.channel.iOSChannelSettings?.isTimeSensitive = (self.authorizedNotificationSettings.rawValue & UAAuthorizedNotificationSettings.timeSensitive.rawValue > 0)

            completionHandler(payload)
        }
    }

    private func analyticsHeaders() -> [String : String] {
        if self.privacyManager.isEnabled(.push) {
            var headers:[String : String] = [:]
            headers["X-UA-Channel-Opted-In"] = self.isPushNotificationsOptedIn ? "true" : "false"
            headers["X-UA-Notification-Prompted"] = self.userPromptedForNotifications ? "true" : "false"
            headers["X-UA-Channel-Background-Enabled"] = self.backgroundPushNotificationsAllowed() ? "true" : "false"
            headers["X-UA-Push-Address"] = self.deviceToken

            return headers
        } else {
            return ["X-UA-Channel-Opted-In" : "false", "X-UA-Channel-Background-Enabled" : "false"]
        }
    }
}

/// - Note: For internal use only. :nodoc:
extension Push: InternalPushProtocol {
    public func didRegisterForRemoteNotifications(_ deviceToken: Data) {
        guard self.privacyManager.isEnabled(.push) else {
            return
        }
        
        let tokenString = Utils.deviceTokenStringFromDeviceToken(deviceToken)
        AirshipLogger.info("Device token string: \(tokenString)")
        self.deviceToken = tokenString
        self.channel.updateRegistration()
        self.registrationDelegate?.apnsRegistrationSucceeded?(withDeviceToken: deviceToken)
    }

    public func didFailToRegisterForRemoteNotifications(_ error: Error) {
        guard self.privacyManager.isEnabled(.push) else {
            return
        }

        self.registrationDelegate?.apnsRegistrationFailedWithError?(error)
    }

    public func presentationOptionsForNotification(_ notification: UNNotification) -> UNNotificationPresentationOptions {
        guard self.privacyManager.isEnabled(.push) else {
            return []
        }

        var options: UNNotificationPresentationOptions = []

        // get foreground presentation options defined from the push API/dashboard
        if let payloadPresentationOptions = self.foregroundPresentationOptions(notification:notification) {
            if payloadPresentationOptions.count > 0 {
                // build the options bitmask from the array
                for presentationOption in payloadPresentationOptions {
                    switch presentationOption {
                    case Push.presentationOptionBadge:
                        options.insert(.badge)
#if !os(watchOS)
                    case Push.presentationOptionAlert:
                        options.insert(.alert)
#endif
                    case Push.presentationOptionSound:
                        options.insert(.sound)
#if !targetEnvironment(macCatalyst)
                    case Push.presentationOptionList:
                        if #available(iOS 14.0, tvOS 14.0, *) {
                            options.insert(.list)
                        }
                    case Push.presentationOptionBanner:
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
                options = self.defaultPresentationOptions
            }
        } else {
            options = self.defaultPresentationOptions
        }

        if let extendedOptions = self.pushNotificationDelegate?.extend?(options, notification: notification) {
            options = extendedOptions
        }

        return options
    }

#if !os(tvOS)

    public func didReceiveNotificationResponse(_ response: UNNotificationResponse, completionHandler: @escaping () -> Void) {
        guard self.privacyManager.isEnabled(.push) else {
            completionHandler()
            return
        }

        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            self.launchNotificationResponse = response
        }

        self.notificationCenter.post(name: Push.receivedNotificationResponseEvent, object: self, userInfo:[Push.receivedNotificationResponseEventResponseKey : response])

        if let callback = self.pushNotificationDelegate?.receivedNotificationResponse {
            callback(response, completionHandler)
        } else {
            completionHandler()
        }
    }
    
#endif


    public func didReceiveRemoteNotification(_ notification: [AnyHashable : Any],
                                             isForeground: Bool,
                                             completionHandler handler: @escaping (Any) -> Void) {

        guard self.privacyManager.isEnabled(.push) else {
#if !os(watchOS)
            handler(UIBackgroundFetchResult.noData)
#else
            handler(WKBackgroundFetchResult.noData)
#endif
            return
        }

        let delegate = self.pushNotificationDelegate

        if (isForeground) {
            self.notificationCenter.post(name: Push.receivedForegroundNotificationEvent, object: self, userInfo: notification)
            if let callback = delegate?.receivedForegroundNotification {
                callback(notification, {
#if !os(watchOS)
            handler(UIBackgroundFetchResult.noData)
#else
            handler(WKBackgroundFetchResult.noData)
#endif
                })
            } else {
#if !os(watchOS)
            handler(UIBackgroundFetchResult.noData)
#else
            handler(WKBackgroundFetchResult.noData)
#endif
            }
        } else {
            self.notificationCenter.post(name: Push.receivedBackgroundNotificationEvent, object: self, userInfo: notification)
            if let callback = delegate?.receivedBackgroundNotification {
                callback(notification, { result in
                    handler(result)
                })
            } else {
#if !os(watchOS)
            handler(UIBackgroundFetchResult.noData)
#else
            handler(WKBackgroundFetchResult.noData)
#endif
            }
        }
    }

    private func foregroundPresentationOptions(notification: UNNotification) -> [String]? {
        var presentationOptions: [String]? = nil
#if !os(tvOS)
        // get the presentation options from the the notification
        presentationOptions = notification.request.content.userInfo[Push.ForegroundPresentationkey] as? [String]

        if (presentationOptions == nil) {
            presentationOptions = notification.request.content.userInfo[Push.ForegroundPresentationLegacykey] as? [String]
        }
#endif
        return presentationOptions
    }
    
    /// - NOTE: For internal use only. :nodoc:
    func resetDeviceToken() {
        self.deviceToken = nil

        self.mainDispatcher.dispatchAsync {
            self.apnsRegistrar.registerForRemoteNotifications()
        }
    }
}
