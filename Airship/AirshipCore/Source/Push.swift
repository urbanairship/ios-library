/* Copyright Airship and Contributors */

import Combine

import Foundation
import UserNotifications

#if os(watchOS)
import WatchKit
import UIKit
#endif

/// This singleton provides an interface to the functionality provided by the Airship iOS Push API.
final class AirshipPush: NSObject, AirshipPushProtocol, @unchecked Sendable {

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

    private let notificationStatusSubject = PassthroughSubject<AirshipNotificationStatus, Never>()
    public var notificationStatusPublisher: AnyPublisher<AirshipNotificationStatus, Never> {
        notificationStatusSubject
            .prepend(Future { promise in
                Task {
                    return await promise(.success(self.notificationStatus))
                }
            })
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

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
    private let channel: InternalAirshipChannelProtocol
    private let privacyManager: AirshipPrivacyManager
    private let permissionsManager: AirshipPermissionsManager
    private let userNotificationCenter: AirshipUserNotificationCenterProtocol
    private let notificationCenter: AirshipNotificationCenter
    private let notificationRegistrar: NotificationRegistrar
    private let apnsRegistrar: APNSRegistrar
    private let badger: Badger

    @MainActor
    private var waitForDeviceToken = false

    @MainActor
    private var pushEnabled = false

    private let serialQueue: AirshipAsyncSerialQueue


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

    private var subscriptions: Set<AnyCancellable> = Set()
    
    @MainActor
    init(
        config: RuntimeConfig,
        dataStore: PreferenceDataStore,
        channel: InternalAirshipChannelProtocol,
        analytics: InternalAnalyticsProtocol,
        privacyManager: AirshipPrivacyManager,
        permissionsManager: AirshipPermissionsManager,
        userNotificationCenter: AirshipUserNotificationCenterProtocol = AirshipUserNotificationCenter.shared,
        notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter.shared,
        notificationRegistrar: NotificationRegistrar =
            UNNotificationRegistrar(),
        apnsRegistrar: APNSRegistrar,
        badger: Badger,
        serialQueue: AirshipAsyncSerialQueue = AirshipAsyncSerialQueue()
    ) {

        self.config = config
        self.dataStore = dataStore
        self.channel = channel
        self.privacyManager = privacyManager
        self.permissionsManager = permissionsManager
        self.notificationCenter = notificationCenter
        self.userNotificationCenter = userNotificationCenter
        self.notificationRegistrar = notificationRegistrar
        self.apnsRegistrar = apnsRegistrar
        self.badger = badger
        self.serialQueue = serialQueue

        super.init()


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
            self.updateNotificationStatus()
        }

        self.waitForDeviceToken = self.channel.identifier == nil
        self.observeNotificationCenterEvents()

        let checkAppRestoreTask = Task {
            if await self.dataStore.isAppRestore {
                self.resetDeviceToken()
            }
        }

        self.channel.addRegistrationExtender { payload in
            await checkAppRestoreTask.value
            return await self.extendChannelRegistrationPayload(
                payload
            )
        }

        analytics.addHeaderProvider {
            await self.analyticsHeaders()
        }

        self.updatePushEnablement()

        if !self.apnsRegistrar.isRemoteNotificationBackgroundModeEnabled {
            AirshipLogger.impError(
                "Application is not configured for background notifications. Please enable remote notifications in the application's background modes."
            )
        }
    }

    @MainActor
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
            name: AirshipNotifications.PrivacyManagerUpdated.name,
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

            self.updateNotificationStatus()
        }

        get {
            return self.dataStore.bool(
                forKey: AirshipPush.userPushNotificationsEnabledKey
            )
        }
    }


    /// When enabled, if the user has ephemeral notification authorization the SDK will prompt the user for
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
                self.updateNotificationStatus()
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
                AirshipLogger.importantInfo("Device token: \(deviceToken)")
            } catch {
                AirshipLogger.error("Unable to set device token")
            }

            self.updateNotificationStatus()
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
    @MainActor
    public var customCategories: Set<UNNotificationCategory> = Set() {
        didSet {
            self.updateCategories()
        }
    }

    /// The combined set of notification categories from `customCategories` set by the app
    /// and the Airship provided categories.
    @objc
    @MainActor
    public var combinedCategories: Set<UNNotificationCategory> {
        let defaultCategories = NotificationCategories.defaultCategories(
            withRequireAuth: requireAuthorizationForDefaultCategories
        )
        return defaultCategories.union(self.customCategories)
    }

    #endif

    /// Sets authorization required for the default Airship categories. Only applies
    /// to background user notification actions.
    ///
    /// Changes to this value will not take effect until the next time the app registers
    /// with updateRegistration.
    @objc
    @MainActor
    public var requireAuthorizationForDefaultCategories = true {
        didSet {
            self.updateCategories()
        }
    }

    @objc
    public weak var pushNotificationDelegate: PushNotificationDelegate?

    @objc
    public weak var registrationDelegate: RegistrationDelegate?

    #if !os(tvOS)
    /// Notification response that launched the application.
    @objc
    public private(set) var launchNotificationResponse: UNNotificationResponse?
    #endif

    @objc
    @MainActor
    public private(set) var authorizedNotificationSettings: UAAuthorizedNotificationSettings {
        set {
            self.dataStore.setInteger(
                Int(newValue.rawValue),
                forKey: AirshipPush.typesAuthorizedKey
            )
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

        updateNotificationStatus()

        if (settingsChanged || alwaysUpdateChannel) {
            self.channel.updateRegistration()
        }

        return(status, settings)
    }

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

    public var notificationStatus: AirshipNotificationStatus {
        get async {
            let (status, settings) = await self.notificationRegistrar.checkStatus()
            let isRegisteredForRemoteNotifications = await self.apnsRegistrar.isRegisteredForRemoteNotifications

            return await AirshipNotificationStatus(
                isUserNotificationsEnabled: self.userPushNotificationsEnabled,
                areNotificationsAllowed: status != .denied && status != .notDetermined && settings != [],
                isPushPrivacyFeatureEnabled: self.privacyManager.isEnabled(.push),
                isPushTokenRegistered: self.deviceToken != nil && isRegisteredForRemoteNotifications
            )
        }
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
        if self.privacyManager.isEnabled(.push) {
            if (!self.pushEnabled) {
                self.pushEnabled = true
                self.apnsRegistrar.registerForRemoteNotifications()
                self.dispatchUpdateNotifications()
                self.updateCategories()
            }
        } else {
            self.pushEnabled = false
        }

        updateNotificationStatus()
    }

    private func updateNotificationStatus() {
        Task { @MainActor in
            self.notificationStatusSubject.send(await self.notificationStatus)
        }
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

    @MainActor
    public func setBadgeNumber(_ newBadgeNumber: Int) async {
        do {
            /// noop for unsupported platforms
            try await userNotificationCenter.setBadgeNumber(newBadgeNumber)
        } catch {
            AirshipLogger.debug(
                "Badge change failed"
            )
            return
        }

        self.badgeNumber = newBadgeNumber
    }

    /// deprecation warning
    @objc
    @MainActor
    internal var badgeNumber: Int {
        set {
            guard badgeNumber != newValue else {
                return
            }

            AirshipLogger.debug(
                "Changed Badge from \(self.badger.applicationIconBadgeNumber), to \(newValue)"
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

    @objc
    @MainActor
    func resetBadge() async {
        await self.setBadgeNumber(0)
    }

    #endif

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

    private func updateRegistration() {
        self.dispatchUpdateNotifications()
    }

    @MainActor
    private func updateCategories() {
        #if !os(tvOS)
        guard 
            self.privacyManager.isEnabled(.push),
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
        guard self.privacyManager.isEnabled(.push) else {
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
            // avoid that by just skipping if we have ephemeral.
            await self.notificationRegistrar.updateRegistration(
                options: [],
                skipIfEphemeral: true
            )

            await self.onNotificationRegistrationFinished()
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
    @MainActor
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
            name: AirshipNotifications.ReceivedNotificationResponse.name,
            object: self,
            userInfo: [
                AirshipNotifications.ReceivedNotificationResponse.responseKey: response
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

        self.notificationCenter.post(
            name: AirshipNotifications.RecievedNotification.name,
            object: self,
            userInfo: [
                AirshipNotifications.RecievedNotification.isForegroundKey: isForeground,
                AirshipNotifications.RecievedNotification.notificationKey: notification
            ]
        )

        if isForeground {
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
        self.waitForDeviceToken = true
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


extension AirshipPush: AirshipComponent {}


public extension AirshipNotifications {

    /// NSNotification info when enabled feature changed on PrivacyManager.
    @objc(UAirshipNotificationReceivedNotificationResponse)
    final class ReceivedNotificationResponse: NSObject {

        /// NSNotification name.
        @objc
        public static let name = NSNotification.Name(
            "com.urbanairship.push.received_notification_response"
        )

        /// NSNotification userInfo key to get the response dictionary.
        public static let responseKey: String = "response"
    }


    /// NSNotification info when enabled feature changed on PrivacyManager.
    @objc(UAirshipNotificationRecievedNotification)
    final class RecievedNotification: NSObject {

        /// NSNotification name.
        @objc
        public static let name = NSNotification.Name(
            "com.urbanairship.push.received_notification"
        )

        /// NSNotification userInfo key to get a boolean if the notification was received in the foreground or not.
        public static let isForegroundKey: String = "is_foreground"

        /// NSNotification userInfo key to get the notification user info.
        public static let notificationKey: String = "notification"
    }
}
