/* Copyright Airship and Contributors */

import Combine
import Foundation
import UserNotifications

#if os(watchOS)
import WatchKit
import UIKit
#endif

/// This singleton provides an interface to the functionality provided by the Airship iOS Push API.
@objc(UAPush)
public class AirshipPush: NSObject, Component, PushProtocol {

    private let pushTokenSubject = PassthroughSubject<String?, Never>()
    private var pushTokenPublisher: AnyPublisher<String?, Never> {
        self.pushTokenSubject
            .prepend(Future { promise in
                Task {
                    return await promise(.success(self.deviceToken))
                }
            })
            .eraseToAnyPublisher()
    }


    private let optInSubject = PassthroughSubject<Bool, Never>()

    /// Push opt-in updates
    public var optInUpdates: AnyPublisher<Bool, Never> {
        optInSubject
            .prepend(Future { promise in
                Task {
                    return await promise(.success(self.isPushNotificationsOptedIn))
                }
            })
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    /// The shared Push instance.
    @objc
    public static var shared: AirshipPush {
        return Airship.push
    }

    /// NSNotification event when a notification response is received.
    /// The event will contain the notification response object.
    @objc
    public static let receivedNotificationResponseEvent = NSNotification.Name(
        "com.urbanairship.push.received_notification_response"
    )

    /// Response key for ReceivedNotificationResponseEvent
    @objc
    public static let receivedNotificationResponseEventResponseKey = "response"

    /// NSNotification event when a foreground notification is received.
    /// The event will contain the payload dictionary as user info.
    @objc
    public static let receivedForegroundNotificationEvent = NSNotification.Name(
        "com.urbanairship.push.received_foreground_notification"
    )

    /// NSNotification event when a background notification is received.
    /// The event will contain the payload dictionary as user info.
    @objc
    public static let receivedBackgroundNotificationEvent = NSNotification.Name(
        "com.urbanairship.push.received_background_notification"
    )

    /// Quiet Time dictionary start key. For internal use only :nodoc:
    @objc
    public static let quietTimeStartKey = "start"

    /// Quiet Time dictionary end key. For internal use only :nodoc:
    @objc
    public static let quietTimeEndKey = "end"

    private static let pushNotificationsOptionsKey =
        "UAUserPushNotificationsOptions"
    private static let userPushNotificationsEnabledKey =
        "UAUserPushNotificationsEnabled"
    private static let backgroundPushNotificationsEnabledKey =
        "UABackgroundPushNotificationsEnabled"
    private static let requestExplicitPermissionWhenEphemeralKey =
        "UAExtendedPushNotificationPermissionEnabled"

    private static let badgeSettingsKey = "UAPushBadge"
    private static let deviceTokenKey = "UADeviceToken"
    private static let quietTimeSettingsKey = "UAPushQuietTime"
    private static let quietTimeEnabledSettingsKey = "UAPushQuietTimeEnabled"
    private static let timeZoneSettingsKey = "UAPushTimeZone"

    private static let typesAuthorizedKey = "UAPushTypesAuthorized"
    private static let authorizationStatusKey = "UAPushAuthorizationStatus"
    private static let userPromptedForNotificationsKey =
        "UAPushUserPromptedForNotifications"

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
    private static let ForegroundPresentationLegacykey =
        "foreground_presentation"
    private static let ForegroundPresentationkey =
        "com.urbanairship.foreground_presentation"
    private static let deviceTokenRegistrationWaitTime: TimeInterval = 10

    private let config: RuntimeConfig
    private let dataStore: PreferenceDataStore
    private let channel: InternalAirshipChannelProtocol
    private let privacyManager: AirshipPrivacyManager
    private let permissionsManager: AirshipPermissionsManager
    private let notificationCenter: NotificationCenter
    private let notificationRegistrar: NotificationRegistrar

    private let apnsRegistrar: APNSRegistrar
    private var badger: Badger

    private let disableHelper: ComponentDisableHelper
    private var shouldUpdateNotificationRegistration = true
    private var waitForDeviceToken = false
    private var pushEnabled = false
    private var deviceTokenAvailableBlock: (() -> Void)?
    private let serialQueue: AsyncSerialQueue


    @MainActor
    private var isRegisteredForRemoteNotifications: Bool {
        return self.apnsRegistrar.isRegisteredForRemoteNotifications
    }

    @MainActor
    private var isBackgroundRefreshStatusAvailable: Bool {
        #if os(watchOS)
        return false
        #else
        return self.apnsRegistrar.isBackgroundRefreshStatusAvailable
        #endif
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

    @MainActor
    init(
        config: RuntimeConfig,
        dataStore: PreferenceDataStore,
        channel: InternalAirshipChannelProtocol,
        analytics: InternalAnalyticsProtocol,
        privacyManager: AirshipPrivacyManager,
        permissionsManager: AirshipPermissionsManager,
        notificationCenter: NotificationCenter = NotificationCenter.default,
        notificationRegistrar: NotificationRegistrar =
            UNNotificationRegistrar(),
        apnsRegistrar: APNSRegistrar,
        badger: Badger,
        serialQueue: AsyncSerialQueue = AsyncSerialQueue()
    ) {

        self.config = config
        self.dataStore = dataStore
        self.channel = channel
        self.privacyManager = privacyManager
        self.permissionsManager = permissionsManager
        self.notificationCenter = notificationCenter
        self.notificationRegistrar = notificationRegistrar
        self.apnsRegistrar = apnsRegistrar
        self.badger = badger
        self.serialQueue = serialQueue

        self.disableHelper = ComponentDisableHelper(
            dataStore: dataStore,
            className: "UAPush"
        )
        super.init()

        self.disableHelper.onChange = { [weak self] in
            self?.onComponentEnableChange()
        }

        if config.requestAuthorizationToUseNotifications {
            let permissionDelegate = NotificationPermissionDelegate(
                registrar: self.notificationRegistrar
            ) {
                let options = self.notificationOptions
                let skipIfEphemeral = !self
                    .requestExplicitPermissionWhenEphemeral
                return NotificationPermissionDelegate.Config(
                    options: options,
                    skipIfEphemeral: skipIfEphemeral
                )
            }

            self.permissionsManager.setDelegate(
                permissionDelegate,
                permission: .displayNotifications
            )
        }

        self.permissionsManager.addRequestExtender(
            permission: .displayNotifications
        ) { status in
            await self.onNotificationRegistrationFinished()
        }

        self.permissionsManager.addAirshipEnabler(
            permission: .displayNotifications
        ) {
            self.dataStore.setBool(
                true,
                forKey: AirshipPush.userPushNotificationsEnabledKey
            )
            self.privacyManager.enableFeatures(.push)
            self.channel.updateRegistration()
            self.optInSubject.send(self.isPushNotificationsOptedIn)
        }

        self.waitForDeviceToken = self.channel.identifier == nil
        self.observeNotificationCenterEvents()

        var checkedAppRestore = false
        self.channel.addRegistrationExtender { payload in
            if !checkedAppRestore && self.dataStore.isAppRestore {
                self.resetDeviceToken()
            }
            checkedAppRestore = true
            return await self.extendChannelRegistrationPayload(
                payload
            )
        }

        analytics.addHeaderProvider(self.analyticsHeaders)

        self.updatePushEnablement()

        if !self.apnsRegistrar.isRemoteNotificationBackgroundModeEnabled {
            AirshipLogger.impError(
                "Application is not configured for background notifications. Please enable remote notifications in the application's background modes."
            )
        }
    }

    private func observeNotificationCenterEvents() {
        #if !os(watchOS)
        self.notificationCenter.addObserver(
            self,
            selector: #selector(applicationBackgroundRefreshStatusChanged),
            name: UIApplication
                .backgroundRefreshStatusDidChangeNotification,
            object: nil
        )
        #endif
        self.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: AppStateTracker.didBecomeActiveNotification,
            object: nil
        )

        self.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: AppStateTracker.didEnterBackgroundNotification,
            object: nil
        )

        self.notificationCenter.addObserver(
            self,
            selector: #selector(onEnabledFeaturesChanged),
            name: AirshipPrivacyManager.changeEvent,
            object: nil
        )
    }

    /// Enables/disables background remote notifications on this device through Airship.
    /// Defaults to `true`.
    @objc
    public var backgroundPushNotificationsEnabled: Bool {
        set {
            let previous = self.backgroundPushNotificationsEnabled
            self.dataStore.setBool(
                newValue,
                forKey: AirshipPush.backgroundPushNotificationsEnabledKey
            )
            if !previous == newValue {
                self.channel.updateRegistration()
            }
        }
        get {
            return self.dataStore.bool(
                forKey: AirshipPush.backgroundPushNotificationsEnabledKey,
                defaultValue: true
            )
        }
    }

    /// Enables/disables user notifications on this device through Airship.
    /// Defaults to `false`. Once set to `true`, the user will be prompted for remote notifications.
    @objc
    public var userPushNotificationsEnabled: Bool {
        set {
            let previous = self.userPushNotificationsEnabled
            self.dataStore.setBool(
                newValue,
                forKey: AirshipPush.userPushNotificationsEnabledKey
            )
            if previous != newValue {
                self.dispatchUpdateNotifications()
            }

            Task {
                self.optInSubject.send(await self.isPushNotificationsOptedIn)
            }
        }

        get {
            return self.dataStore.bool(
                forKey: AirshipPush.userPushNotificationsEnabledKey
            )
        }
    }

    /// Enables/disables extended App Clip user notifications on this device through Airship.
    /// Defaults to `false`. Once set to `true`, the user will be prompted for remote notifications if userPushNotificationsEnabled and the user currently has
    /// ephemeral authorization.
    @objc
    @available(
        *,
        deprecated,
        message: "Use requestExplicitPermissionWhenEphemeral instead"
    )
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
                self.dataStore.setBool(
                    newValue,
                    forKey: AirshipPush.requestExplicitPermissionWhenEphemeralKey
                )
                self.dispatchUpdateNotifications()
            }
        }
        get {
            return self.dataStore.bool(
                forKey: AirshipPush.requestExplicitPermissionWhenEphemeralKey
            )
        }
    }

    /// The device token for this device, as a hex string.
    @objc
    @MainActor
    public private(set) var deviceToken: String? {
        set {
            guard let deviceToken = newValue else {
                self.dataStore.removeObject(forKey: AirshipPush.deviceTokenKey)
                optInSubject.send(isPushNotificationsOptedIn)
                return
            }

            do {
                let regex = try NSRegularExpression(
                    pattern: "[^0-9a-fA-F]",
                    options: .caseInsensitive
                )
                if regex.numberOfMatches(
                    in: deviceToken,
                    options: [],
                    range: NSRange(location: 0, length: deviceToken.count)
                ) != 0 {
                    AirshipLogger.error(
                        "Device token \(deviceToken) contains invalid characters. Only hex characters are allowed"
                    )
                    return
                }

                if deviceToken.count < 64 || deviceToken.count > 200 {
                    AirshipLogger.warn(
                        "Device token \(deviceToken) should be 64 to 200 hex characters (32 to 100 bytes) long."
                    )
                }

                self.dataStore.setObject(
                    deviceToken,
                    forKey: AirshipPush.deviceTokenKey
                )
                self.deviceTokenAvailableBlock?()
                AirshipLogger.importantInfo("Device token: \(deviceToken)")
            } catch {
                AirshipLogger.error("Unable to set device token")
            }

            optInSubject.send(isPushNotificationsOptedIn)
        }

        get {
            return self.dataStore.string(forKey: AirshipPush.deviceTokenKey)
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
            self.dataStore.setObject(
                NSNumber(value: newValue.rawValue),
                forKey: AirshipPush.pushNotificationsOptionsKey
            )
            if previous != newValue {
                self.dispatchUpdateNotifications()
            }
        }

        get {
            guard
                let value = self.dataStore.object(
                    forKey: AirshipPush.pushNotificationsOptionsKey
                ) as? NSNumber
            else {
                #if os(tvOS)
                return .badge
                #else
                guard self.authorizationStatus == .provisional else {
                    return [.badge, .sound, .alert]
                }
                return [.badge, .sound, .alert, .provisional]
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
        let defaultCategories = NotificationCategories.defaultCategories(
            withRequireAuth: requireAuthorizationForDefaultCategories
        )
        return defaultCategories.union(
            self.customCategories.union(self.accengageCategories)
        )
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
    @MainActor
    public private(set) var authorizedNotificationSettings: UAAuthorizedNotificationSettings {
        set {
            self.dataStore.setInteger(
                Int(newValue.rawValue),
                forKey: AirshipPush.typesAuthorizedKey
            )

            optInSubject.send(isPushNotificationsOptedIn)
        }

        get {
            guard
                let value = self.dataStore.object(
                    forKey: AirshipPush.typesAuthorizedKey
                )
                    as? NSNumber
            else {
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
            self.dataStore.setInteger(
                newValue.rawValue,
                forKey: AirshipPush.authorizationStatusKey
            )
        }

        get {
            guard
                let value = self.dataStore.object(
                    forKey: AirshipPush.authorizationStatusKey
                )
                    as? NSNumber
            else {
                return .notDetermined
            }

            return UAAuthorizationStatus(rawValue: Int(value.uintValue))
                ?? .notDetermined
        }
    }

    /// Indicates whether the user has been prompted for notifications or not.
    /// If push is disabled in privacy manager, this value will be out of date.
    @objc
    public private(set) var userPromptedForNotifications: Bool {
        set {
            self.dataStore.setBool(
                newValue,
                forKey: AirshipPush.userPromptedForNotificationsKey
            )
        }
        get {
            return self.dataStore.bool(
                forKey: AirshipPush.userPromptedForNotificationsKey
            )
        }
    }

    /// The default presentation options to use for foreground notifications.
    @objc
    public var defaultPresentationOptions: UNNotificationPresentationOptions =
        []

    @MainActor
    private func updateAuthorizedNotificationTypes(
        alwaysUpdateChannel: Bool = false
    ) async -> (UAAuthorizationStatus, UAAuthorizedNotificationSettings) {
        AirshipLogger.trace("Updating authorized types.")
        let (status, settings) = await self.notificationRegistrar.checkStatus()
        var settingsChanged = false
        if self.privacyManager.isEnabled(.push) {
            if !self.userPromptedForNotifications {
                if status != .notDetermined && status != .ephemeral {
                    self.userPromptedForNotifications = true
                }
            }
            if status != self.authorizationStatus {
                self.authorizationStatus = status
                settingsChanged = true
            }

            if self.authorizedNotificationSettings != settings {
                self.authorizedNotificationSettings = settings
                self.registrationDelegate?.notificationAuthorizedSettingsDidChange?(
                    settings
                )
                settingsChanged = true
            }
        }

        if (settingsChanged || alwaysUpdateChannel) {
            self.channel.updateRegistration()
        }

        return(status, settings)
    }


    /// Enables user notifications on this device through Airship.
    ///
    /// - Note: The completion handler will return the success state of system push authorization as it is defined by the
    /// user's response to the push authorization prompt. The completion handler success state does NOT represent the
    /// state of the userPushNotificationsEnabled flag, which will be invariably set to `true` after the completion of this call.
    ///
    /// - Parameter completionHandler: The completion handler with success flag representing the system authorization state.
    @objc
    public func enableUserPushNotifications() async -> Bool {
        self.dataStore.setBool(
            true,
            forKey: AirshipPush.userPushNotificationsEnabledKey
        )
        return await self.permissionsManager.requestPermission(.displayNotifications) == .granted
    }
    
    @MainActor
    private func waitForDeviceTokenRegistration() async {
        guard self.waitForDeviceToken,
              self.privacyManager.isEnabled(.push),
              self.deviceToken == nil,
              self.apnsRegistrar.isRegisteredForRemoteNotifications
        else {
            return
        }

        self.waitForDeviceToken = false

        var subscription: AnyCancellable?
        defer {
            subscription?.cancel()
        }

        await withCheckedContinuation { continuation in
            let cancelTask = Task { @MainActor in
                try await Task.sleep(
                    nanoseconds: UInt64(AirshipPush.deviceTokenRegistrationWaitTime * 1_000_000_000)
                )
                subscription?.cancel()
                try Task.checkCancellation()
                continuation.resume()
            }

            subscription = self.pushTokenPublisher
                .receive(on: RunLoop.main)
                .sink { token in
                    if (token != nil) {
                        continuation.resume()
                        cancelTask.cancel()
                        subscription?.cancel()
                    }
                }
        }
    }

    /// Indicates whether the user is opted in for push notifications or not.
    @objc
    @MainActor
    public var isPushNotificationsOptedIn: Bool {
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
            AirshipLogger.trace(
                "Opted out: no authorized notification settings"
            )
            optedIn = false
        }

        if !self.isRegisteredForRemoteNotifications {
            AirshipLogger.trace(
                "Opted out: not registered for remote notifications"
            )
            optedIn = false
        }

        if !self.privacyManager.isEnabled(.push) {
            AirshipLogger.trace("Opted out: push is disabled")
            optedIn = false
        }

        return optedIn
    }

    @MainActor
    private func backgroundPushNotificationsAllowed() -> Bool {
        guard self.deviceToken != nil,
            self.backgroundPushNotificationsEnabled,
            self.apnsRegistrar.isRemoteNotificationBackgroundModeEnabled,
            self.privacyManager.isEnabled(.push)
        else {
            return false
        }

        return self.isRegisteredForRemoteNotifications
            && self.isBackgroundRefreshStatusAvailable
    }

    @MainActor
    private func updatePushEnablement() {
        if self.isComponentEnabled && self.privacyManager.isEnabled(.push) {
            if (!self.pushEnabled) {
                self.pushEnabled = true
                self.apnsRegistrar.registerForRemoteNotifications()
                self.dispatchUpdateNotifications()
                self.updateCategories()
            }
        } else {
            self.pushEnabled = false
        }

        optInSubject.send(isPushNotificationsOptedIn)
    }

    @MainActor
    private func onNotificationRegistrationFinished() async {
        guard self.privacyManager.isEnabled(.push) else {
            return
        }
        
        if self.deviceToken == nil {
            self.apnsRegistrar.registerForRemoteNotifications()
        }

        let (status, settings) = await self.updateAuthorizedNotificationTypes(
            alwaysUpdateChannel: true
        )

        #if !os(tvOS)
        self.registrationDelegate?
            .notificationRegistrationFinished?(
                withAuthorizedSettings: settings,
                categories: self.combinedCategories,
                status: status
            )

        #else
        self.registrationDelegate?
            .notificationRegistrationFinished?(
                withAuthorizedSettings: settings,
                status: status
            )
        #endif
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

            AirshipLogger.debug(
                "Change Badge from \(self.badger.applicationIconBadgeNumber), to \(newValue)"
            )

            self.badger.applicationIconBadgeNumber = newValue

            if self.autobadgeEnabled {
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
                self.dataStore.setBool(
                    newValue,
                    forKey: AirshipPush.badgeSettingsKey
                )
                self.channel.updateRegistration(forcefully: true)
            }
        }

        get {
            return self.dataStore.bool(forKey: AirshipPush.badgeSettingsKey)
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
    public private(set) var quietTime: [AnyHashable: Any]? {
        set {
            self.dataStore.setObject(
                newValue,
                forKey: AirshipPush.quietTimeSettingsKey
            )
            self.channel.updateRegistration()
        }

        get {
            return self.dataStore.dictionary(forKey: AirshipPush.quietTimeSettingsKey)
        }
    }

    /// Time Zone for quiet time. If the time zone is not set, the current
    /// local time zone is returned.
    @objc
    public var timeZone: NSTimeZone? {
        set {
            self.dataStore.setObject(
                newValue?.name ?? nil,
                forKey: AirshipPush.timeZoneSettingsKey
            )
        }

        get {
            let timeZoneName =
                self.dataStore.string(forKey: AirshipPush.timeZoneSettingsKey) ?? ""
            return NSTimeZone(name: timeZoneName) ?? NSTimeZone.default
                as NSTimeZone
        }
    }

    /// Enables/Disables quiet time
    @objc
    public var quietTimeEnabled: Bool {
        set {
            self.dataStore.setBool(
                newValue,
                forKey: AirshipPush.quietTimeEnabledSettingsKey
            )
        }

        get {
            return self.dataStore.bool(forKey: AirshipPush.quietTimeEnabledSettingsKey)
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
        let startTimeString =
            "\(String(format: "%02d", startHour)):\(String(format: "%02d", startMinute))"
        let endTimeString =
            "\(String(format: "%02d", endHour)):\(String(format: "%02d", endMinute))"

        if startHour >= 24 || startMinute >= 60 {
            AirshipLogger.error(
                "Unable to set quiet time, invalid start time: \(startTimeString)"
            )
            return
        }

        if endHour >= 24 || endMinute >= 60 {
            AirshipLogger.error(
                "Unable to set quiet time, invalid end time: \(endTimeString)"
            )
            return
        }

        AirshipLogger.debug(
            "Setting quiet time: \(startTimeString) to \(endTimeString)"
        )

        self.quietTime = [
            AirshipPush.quietTimeStartKey: startTimeString,
            AirshipPush.quietTimeEndKey: endTimeString,
        ]
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
        self.serialQueue.enqueue {
            await self.updateNotifications()
        }
    }

    @MainActor
    private func updateNotifications() async {
        guard self.isComponentEnabled,
              self.privacyManager.isEnabled(Features.push)
        else {
            return
        }

        guard self.config.requestAuthorizationToUseNotifications else {
            self.channel.updateRegistration()
            return
        }

        if self.userPushNotificationsEnabled {
            _ = await self.permissionsManager.requestPermission(.displayNotifications)
        } else {
            // If we are going from `ephemeral` to `[]` it will prompt the user to disable notifications...
            // avoid that by just skippping if we have ephemeral.
            await self.notificationRegistrar.updateRegistration(
                options: [],
                skipIfEphemeral: true
            )

            await self.onNotificationRegistrationFinished()
        }
    }

    /// - Note: For internal use only. :nodoc:
    private func onComponentEnableChange() {
        self.serialQueue.enqueue {
            await self.updatePushEnablement()
        }
    }

    @objc
    private func onEnabledFeaturesChanged() {
        self.serialQueue.enqueue {
            await self.updatePushEnablement()
        }
    }

    @objc
    private func applicationDidBecomeActive() {
        if self.privacyManager.isEnabled(.push) {
            self.dispatchUpdateAuthorizedNotificationTypes()
        }
    }

    @objc
    private func applicationDidEnterBackground() {
        #if !os(tvOS)
        self.launchNotificationResponse = nil
        #endif
        if self.privacyManager.isEnabled(.push) {
            self.dispatchUpdateAuthorizedNotificationTypes()
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

    @MainActor
    private func extendChannelRegistrationPayload(
        _ payload: ChannelRegistrationPayload
    ) async -> ChannelRegistrationPayload {
        var payload = payload

        guard self.privacyManager.isEnabled(.push) else {
            return payload
        }

        await self.waitForDeviceTokenRegistration()

        guard self.privacyManager.isEnabled(.push) else {
            return payload
        }


        payload.channel.pushAddress = self.deviceToken
        payload.channel.isOptedIn = self.isPushNotificationsOptedIn
#if !os(watchOS)
        payload.channel.isBackgroundEnabled =
        self.backgroundPushNotificationsAllowed()
#endif

        payload.channel.iOSChannelSettings =
        payload.channel.iOSChannelSettings
        ?? ChannelRegistrationPayload.iOSChannelSettings()

#if !os(watchOS)
        if self.autobadgeEnabled {
            payload.channel.iOSChannelSettings?.badge = self.badgeNumber
        }
#endif

        if let timeZoneName = self.timeZone?.name,
           let quietTimeStart = self.quietTime?[AirshipPush.quietTimeStartKey]
            as? String,
           let quietTimeEnd = self.quietTime?[AirshipPush.quietTimeEndKey]
            as? String,
           self.quietTimeEnabled
        {

            let quietTime = ChannelRegistrationPayload.QuietTime(
                start: quietTimeStart,
                end: quietTimeEnd
            )
            payload.channel.iOSChannelSettings?.quietTimeTimeZone =
            timeZoneName
            payload.channel.iOSChannelSettings?.quietTime = quietTime
        }

        payload.channel.iOSChannelSettings?.isScheduledSummary =
        (self.authorizedNotificationSettings.rawValue
         & UAAuthorizedNotificationSettings.scheduledDelivery
            .rawValue > 0)
        payload.channel.iOSChannelSettings?.isTimeSensitive =
        (self.authorizedNotificationSettings.rawValue
         & UAAuthorizedNotificationSettings.timeSensitive.rawValue
         > 0)

        return payload
    }

    @MainActor
    private func analyticsHeaders() -> [String: String] {
        guard self.privacyManager.isEnabled(.push) else {
            return [
                "X-UA-Channel-Opted-In": "false",
                "X-UA-Channel-Background-Enabled": "false",
            ]
        }
        var headers: [String: String] = [:]
        headers["X-UA-Channel-Opted-In"] =
            self.isPushNotificationsOptedIn ? "true" : "false"
        headers["X-UA-Notification-Prompted"] =
            self.userPromptedForNotifications ? "true" : "false"
        headers["X-UA-Channel-Background-Enabled"] =
            self.backgroundPushNotificationsAllowed() ? "true" : "false"
        headers["X-UA-Push-Address"] = self.deviceToken

        return headers
    }
}

/// - Note: For internal use only. :nodoc:
extension AirshipPush: InternalPushProtocol {

    public func dispatchUpdateAuthorizedNotificationTypes() {
        self.serialQueue.enqueue {
            _ = await self.updateAuthorizedNotificationTypes()
        }
    }

    @MainActor
    public func didRegisterForRemoteNotifications(_ deviceToken: Data) {
        guard self.privacyManager.isEnabled(.push) else {
            return
        }

        let tokenString = AirshipUtils.deviceTokenStringFromDeviceToken(deviceToken)
        AirshipLogger.info("Device token string: \(tokenString)")
        self.deviceToken = tokenString
        self.channel.updateRegistration()
        self.registrationDelegate?.apnsRegistrationSucceeded?(
            withDeviceToken: deviceToken
        )
    }

    public func didFailToRegisterForRemoteNotifications(_ error: Error) {
        guard self.privacyManager.isEnabled(.push) else {
            return
        }

        self.registrationDelegate?.apnsRegistrationFailedWithError?(error)
    }

    public func presentationOptionsForNotification(
        _ notification: UNNotification,
        completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        guard self.privacyManager.isEnabled(.push) else {
            completionHandler([])
            return
        }

        var options: UNNotificationPresentationOptions = []

        // get foreground presentation options defined from the push API/dashboard
        if let payloadPresentationOptions = self.foregroundPresentationOptions(
            notification: notification
        ) {
            if payloadPresentationOptions.count > 0 {
                // build the options bitmask from the array
                for presentationOption in payloadPresentationOptions {
                    switch presentationOption {
                    case AirshipPush.presentationOptionBadge:
                        options.insert(.badge)
                    case AirshipPush.presentationOptionAlert:
                        options.insert(.list)
                        options.insert(.banner)
                    case AirshipPush.presentationOptionSound:
                        options.insert(.sound)
                    case AirshipPush.presentationOptionList:
                        options.insert(.list)
                    case AirshipPush.presentationOptionBanner:
                        options.insert(.banner)
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

        if let extendedOptions = self.pushNotificationDelegate?.extend?(
            options,
            notification: notification
        ) {
            options = extendedOptions
        }
        
        if let delegateMethod = self.pushNotificationDelegate?.extendPresentationOptions {
            delegateMethod(options, notification, completionHandler)
        } else {
            completionHandler(options)
        }
    }

    #if !os(tvOS)

    public func didReceiveNotificationResponse(
        _ response: UNNotificationResponse,
        completionHandler: @escaping () -> Void
    ) {
        guard self.privacyManager.isEnabled(.push) else {
            completionHandler()
            return
        }

        if response.actionIdentifier
            == UNNotificationDefaultActionIdentifier
        {
            self.launchNotificationResponse = response
        }

        self.notificationCenter.post(
            name: AirshipPush.receivedNotificationResponseEvent,
            object: self,
            userInfo: [
                AirshipPush.receivedNotificationResponseEventResponseKey: response
            ]
        )

        if let callback = self.pushNotificationDelegate?
            .receivedNotificationResponse
        {
            callback(response, completionHandler)
        } else {
            completionHandler()
        }
    }

    #endif

    public func didReceiveRemoteNotification(
        _ notification: [AnyHashable: Any],
        isForeground: Bool,
        completionHandler handler: @escaping (Any) -> Void
    ) {

        guard self.privacyManager.isEnabled(.push) else {
            #if !os(watchOS)
            handler(UIBackgroundFetchResult.noData)
            #else
            handler(WKBackgroundFetchResult.noData)
            #endif
            return
        }

        let delegate = self.pushNotificationDelegate

        if isForeground {
            self.notificationCenter.post(
                name: AirshipPush.receivedForegroundNotificationEvent,
                object: self,
                userInfo: notification
            )
            if let callback = delegate?.receivedForegroundNotification {
                callback(
                    notification,
                    {
                        #if !os(watchOS)
                        handler(UIBackgroundFetchResult.noData)
                        #else
                        handler(WKBackgroundFetchResult.noData)
                        #endif
                    }
                )
            } else {
                #if !os(watchOS)
                handler(UIBackgroundFetchResult.noData)
                #else
                handler(WKBackgroundFetchResult.noData)
                #endif
            }
        } else {
            self.notificationCenter.post(
                name: AirshipPush.receivedBackgroundNotificationEvent,
                object: self,
                userInfo: notification
            )
            if let callback = delegate?.receivedBackgroundNotification {
                callback(
                    notification,
                    { result in
                        handler(result)
                    }
                )
            } else {
                #if !os(watchOS)
                handler(UIBackgroundFetchResult.noData)
                #else
                handler(WKBackgroundFetchResult.noData)
                #endif
            }
        }
    }

    private func foregroundPresentationOptions(notification: UNNotification)
        -> [String]?
    {
        var presentationOptions: [String]? = nil
        #if !os(tvOS)
        // get the presentation options from the the notification
        presentationOptions =
            notification.request.content.userInfo[
                AirshipPush.ForegroundPresentationkey
            ]
            as? [String]

        if presentationOptions == nil {
            presentationOptions =
                notification.request.content.userInfo[
                    AirshipPush.ForegroundPresentationLegacykey
                ] as? [String]
        }
        #endif
        return presentationOptions
    }

    /// - NOTE: For internal use only. :nodoc:
    @MainActor
    func resetDeviceToken() {
        self.deviceToken = nil
        self.apnsRegistrar.registerForRemoteNotifications()
    }
}

#if !os(tvOS)
extension UNNotification {
    
    /// Checks if the push was sent from Airship.
    /// - Returns: true if it's an Airship notification, otherwise false.
    public func isAirshipPush() -> Bool {
        return self.request.content.userInfo["com.urbanairship.metadata"] != nil
    }
    
}
#endif
