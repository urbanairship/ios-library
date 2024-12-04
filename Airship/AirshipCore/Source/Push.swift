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

    private let pushTokenChannel = AirshipAsyncChannel<String>()

    private let notificationStatusChannel = AirshipAsyncChannel<AirshipNotificationStatus>()

    public var notificationStatusPublisher: AnyPublisher<AirshipNotificationStatus, Never> {
        return notificationStatusUpdates
            .airshipPublisher
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
    
    var notificationStatusUpdates: AsyncStream<AirshipNotificationStatus> {
        return self.notificationStatusChannel.makeNonIsolatedDedupingStream(
            initialValue: { [weak self] in await self?.notificationStatus }
        )
    }

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
    private let channel: InternalAirshipChannelProtocol
    private let privacyManager: AirshipPrivacyManager
    private let permissionsManager: AirshipPermissionsManager
    private let notificationCenter: AirshipNotificationCenter
    private let notificationRegistrar: NotificationRegistrar
    private let apnsRegistrar: APNSRegistrar
    private let badger: BadgerProtocol

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
        notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter.shared,
        notificationRegistrar: NotificationRegistrar =
            UNNotificationRegistrar(),
        apnsRegistrar: APNSRegistrar,
        badger: BadgerProtocol,
        serialQueue: AirshipAsyncSerialQueue = AirshipAsyncSerialQueue()
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

        super.init()

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
                Task {
                    await self.pushTokenChannel.send(deviceToken)
                }
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
    @MainActor
    public var customCategories: Set<UNNotificationCategory> = Set() {
        didSet {
            self.updateCategories()
        }
    }

    /// The combined set of notification categories from `customCategories` set by the app
    /// and the Airship provided categories.
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
    @MainActor
    public var requireAuthorizationForDefaultCategories = true {
        didSet {
            self.updateCategories()
        }
    }

    public weak var pushNotificationDelegate: PushNotificationDelegate?

    public weak var registrationDelegate: RegistrationDelegate?

    #if !os(tvOS)
    /// Notification response that launched the application.
    public private(set) var launchNotificationResponse: UNNotificationResponse?
    #endif

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
                self.registrationDelegate?.notificationAuthorizedSettingsDidChange(
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

    public func enableUserPushNotifications() async -> Bool {
        return await enableUserPushNotifications(fallback: .none)
    }

    public func enableUserPushNotifications(
        fallback: PromptPermissionFallback
    ) async -> Bool {
        guard self.config.requestAuthorizationToUseNotifications else {
            self.userPushNotificationsEnabled = true

            if !fallback.isNone {
                AirshipLogger.error(
                    "Airship.push.enableUserPushNotifications(fallback:) called but the AirshipConfig.requestAuthorizationToUseNotifications is disabled. Unable to request permissions. Use Airship.permissionsManager.requestPermission(.displayNotifications, enableAirshipUsageOnGrant: true, fallback: fallback) instead."
                )
            }

            return await self.permissionsManager.checkPermissionStatus(.displayNotifications) == .granted
        }

        self.dataStore.setBool(
            true,
            forKey: AirshipPush.userPushNotificationsEnabledKey
        )

        let result = await self.permissionsManager.requestPermission(
            .displayNotifications,
            enableAirshipUsageOnGrant: false,
            fallback: fallback
        )

        return result.endStatus == .granted
    }

    @MainActor
    private func waitForDeviceTokenRegistration() async {
        guard self.waitForDeviceToken,
              self.privacyManager.isEnabled(.push),
              self.apnsRegistrar.isRegisteredForRemoteNotifications
        else {
            return
        }

        self.waitForDeviceToken = false

        let updates = await pushTokenChannel.makeStream()
        guard self.deviceToken == nil else {
            return
        }

        let waitTask = Task {
            for await _ in updates {
                return
            }
        }

        let cancelTask = Task { @MainActor in
            try await Task.sleep(
                nanoseconds: UInt64(AirshipPush.deviceTokenRegistrationWaitTime * 1_000_000_000)
            )
            try Task.checkCancellation()
            waitTask.cancel()
        }

        await waitTask.value
        cancelTask.cancel()
    }

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
            let displayNotificationStatus = await self.permissionsManager.checkPermissionStatus(.displayNotifications)

            return await AirshipNotificationStatus(
                isUserNotificationsEnabled: self.userPushNotificationsEnabled,
                areNotificationsAllowed: status != .denied && status != .notDetermined && settings != [],
                isPushPrivacyFeatureEnabled: self.privacyManager.isEnabled(.push),
                isPushTokenRegistered: self.deviceToken != nil && isRegisteredForRemoteNotifications,
                displayNotificationStatus: displayNotificationStatus
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
        Task {
            await self.notificationStatusChannel.send(await self.notificationStatus)
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
            .notificationRegistrationFinished(
                withAuthorizedSettings: settings,
                categories: self.combinedCategories,
                status: status
            )

        #else
        self.registrationDelegate?
            .notificationRegistrationFinished(
                withAuthorizedSettings: settings,
                status: status
            )
        #endif
    }

    #if !os(watchOS)

    public func setBadgeNumber(_ newBadgeNumber: Int) async throws {
        try await self.badger.setBadgeNumber(newBadgeNumber)
        if self.autobadgeEnabled {
            self.channel.updateRegistration(forcefully: true)
        }
    }

    /// deprecation warning
    @MainActor
    public var badgeNumber: Int {
        get {
            return self.badger.badgeNumber
        }
    }

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

    @MainActor
    func resetBadge() async throws {
        try await self.setBadgeNumber(0)
    }

    #endif

    public var quietTime: QuietTimeSettings? {
        get {
            guard let quietTime = self.dataStore.dictionary(forKey: Self.quietTimeSettingsKey) else {
                return nil
            }

            return QuietTimeSettings(from: quietTime)
        }
        set {
            if let newValue {
                AirshipLogger.debug("Setting quiet time: \(newValue)")
                self.dataStore.setObject(newValue.dictionary, forKey: Self.quietTimeSettingsKey)
            } else {
                AirshipLogger.debug("Clearing quiet time")
                self.dataStore.removeObject(forKey: Self.quietTimeSettingsKey)
            }
            self.channel.updateRegistration()
        }
    }

    /// Time Zone for quiet time. If the time zone is not set, the current
    /// local time zone is returned.
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

    public func setQuietTimeStartHour(
        _ startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int
    ) {
        do {
            self.quietTime = try QuietTimeSettings(
                startHour: UInt(startHour),
                startMinute: UInt(startMinute),
                endHour: UInt(endHour),
                endMinute: UInt(endMinute)
            )
        } catch {
            AirshipLogger.error(
                "Unable to set quiet time, invalid time: \(error)"
            )
        }
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

        if let timeZoneName = self.timeZone?.name, let quietTime, self.quietTimeEnabled {
            let quietTime = ChannelRegistrationPayload.QuietTime(
                start: quietTime.startString,
                end: quietTime.endString
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
        self.registrationDelegate?.apnsRegistrationSucceeded(
            withDeviceToken: deviceToken
        )
    }

    public func didFailToRegisterForRemoteNotifications(_ error: Error) {
        guard self.privacyManager.isEnabled(.push) else {
            return
        }

        self.registrationDelegate?.apnsRegistrationFailedWithError(error)
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

        if let extendedOptions = self.pushNotificationDelegate?.extend(
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
    final class ReceivedNotificationResponse: NSObject {

        /// NSNotification name.
        public static let name = NSNotification.Name(
            "com.urbanairship.push.received_notification_response"
        )

        /// NSNotification userInfo key to get the response dictionary.
        public static let responseKey: String = "response"
    }


    /// NSNotification info when enabled feature changed on PrivacyManager.
    final class RecievedNotification: NSObject {

        /// NSNotification name.
        public static let name = NSNotification.Name(
            "com.urbanairship.push.received_notification"
        )

        /// NSNotification userInfo key to get a boolean if the notification was received in the foreground or not.
        public static let isForegroundKey: String = "is_foreground"

        /// NSNotification userInfo key to get the notification user info.
        public static let notificationKey: String = "notification"
    }
}

/// Quiet time settings
public struct QuietTimeSettings: Sendable, Equatable {
    private static let quietTimeStartKey = "start"
    private static let quietTimeEndKey = "end"

    /// Start hour
    public let startHour: UInt
    /// Start minute
    public let startMinute: UInt
    /// End hour
    public let endHour: UInt
    /// End minute
    public let endMinute: UInt


    var startString: String {
        return "\(String(format: "%02d", startHour)):\(String(format: "%02d", startMinute))"
    }

    var endString: String {
        return "\(String(format: "%02d", endHour)):\(String(format: "%02d", endMinute))"
    }

    var dictionary: [AnyHashable: Any] {
        return [
            Self.quietTimeStartKey: startString,
            Self.quietTimeEndKey: endString,
        ]
    }

    /// Default constructor.
    /// - Parameters:
    ///     - startHour: The starting hour. Must be between 0-23.
    ///     - startMinute: The starting minute. Must be between 0-59.
    ///     - endHour: The ending hour. Must be between 0-23.
    ///     - endMinute: The ending minute. Must be between 0-59.
    public init(startHour: UInt, startMinute: UInt, endHour: UInt, endMinute: UInt) throws {
        guard startHour < 24, startMinute < 60 else {
            throw AirshipErrors.error("Invalid start time")
        }

        guard endHour < 24, endMinute < 60 else {
            throw AirshipErrors.error("Invalid end time")
        }

        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
    }

    fileprivate init?(from dictionary: [AnyHashable: Any])  {
        guard
            let startTime = dictionary[Self.quietTimeStartKey] as? String,
            let endTime = dictionary[Self.quietTimeEndKey] as? String
        else {
            return nil
        }

        let startParts = startTime.components(separatedBy:":").compactMap { UInt($0) }
        let endParts = endTime.components(separatedBy:":").compactMap { UInt($0) }

        guard startParts.count == 2, endParts.count == 2 else { return nil }

        self.startHour = startParts[0]
        self.startMinute = startParts[1]
        self.endHour = endParts[0]
        self.endMinute = endParts[1]
    }
}
