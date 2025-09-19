/* Copyright Airship and Contributors */

import Combine
import Foundation

@preconcurrency
import UserNotifications

#if canImport(WatchKit)
import WatchKit
#endif

#if canImport(UIKit)
import UIKit
#endif


/// This singleton provides an interface to the functionality provided by the Airship iOS Push API.
final class DefaultAirshipPush: AirshipPush, @unchecked Sendable {

    private let pushTokenChannel = AirshipAsyncChannel<String>()

    private let notificationStatusChannel = AirshipAsyncChannel<AirshipNotificationStatus>()

    @MainActor
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
    private let channel: any InternalAirshipChannel
    private let privacyManager: any AirshipPrivacyManager
    private let permissionsManager: AirshipPermissionsManager
    private let notificationCenter: AirshipNotificationCenter
    private let notificationRegistrar: any NotificationRegistrar
    private let apnsRegistrar: any APNSRegistrar
    private let badger: any BadgerProtocol

    @MainActor
    private var waitForDeviceToken = false

    @MainActor
    private var pushEnabled = false

    private let serialQueue: AirshipAsyncSerialQueue

    @MainActor
    public var onAPNSRegistrationFinished: (@MainActor @Sendable (APNSRegistrationResult) -> Void)?

    @MainActor
    public var onNotificationRegistrationFinished: (@MainActor @Sendable (NotificationRegistrationResult) -> Void)?

    @MainActor
    public var onNotificationAuthorizedSettingsDidChange: (@MainActor @Sendable (AirshipAuthorizedNotificationSettings) -> Void)?

    // Notification callbacks
    @MainActor
    public var onForegroundNotificationReceived: (@MainActor @Sendable ([AnyHashable: Any]) async -> Void)?

#if !os(watchOS)
    @MainActor
    public var onBackgroundNotificationReceived: (@MainActor @Sendable ([AnyHashable: Any]) async -> UIBackgroundFetchResult)?
#else
    @MainActor
    public var onBackgroundNotificationReceived: (@MainActor @Sendable ([AnyHashable: Any]) async -> WKBackgroundFetchResult)?
#endif

    #if !os(tvOS)
    @MainActor
    public var onNotificationResponseReceived: (@MainActor @Sendable (UNNotificationResponse) async -> Void)?
    #endif

    @MainActor
    public var onExtendPresentationOptions: (@MainActor @Sendable (UNNotificationPresentationOptions, UNNotification) async -> UNNotificationPresentationOptions)?

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
        channel: any InternalAirshipChannel,
        analytics: any InternalAirshipAnalytics,
        privacyManager: any AirshipPrivacyManager,
        permissionsManager: AirshipPermissionsManager,
        notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter.shared,
        notificationRegistrar: any NotificationRegistrar =
        UNNotificationRegistrar(),
        apnsRegistrar: any APNSRegistrar,
        badger: any BadgerProtocol,
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
            await self.notificationRegistrationFinished()
        }

        self.permissionsManager.addAirshipEnabler(
            permission: .displayNotifications
        ) {
            self.dataStore.setBool(
                true,
                forKey: DefaultAirshipPush.userPushNotificationsEnabledKey
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
            return await self.extendChannelRegistrationPayload(&payload)
        }

        analytics.addHeaderProvider {
            await self.analyticsHeaders()
        }

        self.updatePushEnablement()

        if !self.apnsRegistrar.isRemoteNotificationBackgroundModeEnabled {
            AirshipLogger.impError(
                "Application is not configured for background notifications. Please enable remote notifications in the application's background modes.",
                skipLogLevelCheck: false
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
                forKey: DefaultAirshipPush.backgroundPushNotificationsEnabledKey
            )
            if !previous == newValue {
                self.channel.updateRegistration()
            }
        }
        get {
            return self.dataStore.bool(
                forKey: DefaultAirshipPush.backgroundPushNotificationsEnabledKey,
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
                forKey: DefaultAirshipPush.userPushNotificationsEnabledKey
            )
            if previous != newValue {
                self.dispatchUpdateNotifications()
            }

            self.updateNotificationStatus()
        }

        get {
            return self.dataStore.bool(
                forKey: DefaultAirshipPush.userPushNotificationsEnabledKey
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
                    forKey: DefaultAirshipPush.requestExplicitPermissionWhenEphemeralKey
                )
                self.dispatchUpdateNotifications()
            }
        }
        get {
            return self.dataStore.bool(
                forKey: DefaultAirshipPush.requestExplicitPermissionWhenEphemeralKey
            )
        }
    }

    /// The device token for this device, as a hex string.
    @MainActor
    public private(set) var deviceToken: String? {
        set {
            guard let deviceToken = newValue else {
                self.dataStore.removeObject(forKey: DefaultAirshipPush.deviceTokenKey)
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
                    forKey: DefaultAirshipPush.deviceTokenKey
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
            return self.dataStore.string(forKey: DefaultAirshipPush.deviceTokenKey)
        }
    }

    /// User Notification options this app will request from APNS. Changes to this value
    /// will not take effect until the next time the app registers with
    /// updateRegistration.
    ///
    /// Defaults to alert, sound and badge.
    public var notificationOptions: UNAuthorizationOptions {
        set {
            let previous = self.notificationOptions
            self.dataStore.setObject(
                newValue.rawValue,
                forKey: DefaultAirshipPush.pushNotificationsOptionsKey
            )
            if previous != newValue {
                self.dispatchUpdateNotifications()
            }
        }

        get {
            guard
                let value = self.dataStore.object(
                    forKey: DefaultAirshipPush.pushNotificationsOptionsKey
                ) as? UInt
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

            return UNAuthorizationOptions(rawValue: value)
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

    @MainActor
    public weak var pushNotificationDelegate: (any PushNotificationDelegate)?

    @MainActor
    public weak var registrationDelegate: (any RegistrationDelegate)?

    #if !os(tvOS)
    /// Notification response that launched the application.
    public private(set) var launchNotificationResponse: UNNotificationResponse?
    #endif

    public private(set) var authorizedNotificationSettings: AirshipAuthorizedNotificationSettings {
        set {
            self.dataStore.setInteger(
                Int(newValue.rawValue),
                forKey: DefaultAirshipPush.typesAuthorizedKey
            )
        }

        get {
            guard
                let value = self.dataStore.object(
                    forKey: DefaultAirshipPush.typesAuthorizedKey
                )
                    as? Int
            else {
                return []
            }

            return AirshipAuthorizedNotificationSettings(rawValue: UInt(value))
        }
    }

    public private(set) var authorizationStatus: UNAuthorizationStatus {
        set {
            self.dataStore.setInteger(
                newValue.rawValue,
                forKey: DefaultAirshipPush.authorizationStatusKey
            )
        }

        get {
            guard
                let value = self.dataStore.object(
                    forKey: DefaultAirshipPush.authorizationStatusKey
                )
                    as? Int
            else {
                return .notDetermined
            }

            return UNAuthorizationStatus(rawValue: Int(value))
                ?? .notDetermined
        }
    }

    public private(set) var userPromptedForNotifications: Bool {
        set {
            self.dataStore.setBool(
                newValue,
                forKey: DefaultAirshipPush.userPromptedForNotificationsKey
            )
        }
        get {
            return self.dataStore.bool(
                forKey: DefaultAirshipPush.userPromptedForNotificationsKey
            )
        }
    }

    public var defaultPresentationOptions: UNNotificationPresentationOptions =
        []

    @MainActor
    private func updateAuthorizedNotificationTypes(
        alwaysUpdateChannel: Bool = false
    ) async -> (UNAuthorizationStatus, AirshipAuthorizedNotificationSettings) {
        AirshipLogger.trace("Updating authorized types.")
        let (status, settings) = await self.notificationRegistrar.checkStatus()
        var settingsChanged = false
        if self.privacyManager.isEnabled(.push) {
            if !self.userPromptedForNotifications {
                #if os(tvOS) || os(watchOS)
                self.userPromptedForNotifications = status != .notDetermined
                #else
                if status != .notDetermined && status != .ephemeral {
                    self.userPromptedForNotifications = true
                }
                #endif
            }
            if status != self.authorizationStatus {
                self.authorizationStatus = status
                settingsChanged = true
            }

            if self.authorizedNotificationSettings != settings {
                self.authorizedNotificationSettings = settings

                if let onNotificationAuthorizedSettingsDidChange {
                    onNotificationAuthorizedSettingsDidChange(settings)
                } else {
                    self.registrationDelegate?.notificationAuthorizedSettingsDidChange(
                        settings
                    )
                }

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
        guard self.config.airshipConfig.requestAuthorizationToUseNotifications else {
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
            forKey: DefaultAirshipPush.userPushNotificationsEnabledKey
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
                nanoseconds: UInt64(DefaultAirshipPush.deviceTokenRegistrationWaitTime * 1_000_000_000)
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
    private func notificationRegistrationFinished() async {
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
        if let onNotificationRegistrationFinished {
            onNotificationRegistrationFinished(
                NotificationRegistrationResult(
                    authorizedSettings: settings,
                    status: status,
                    categories: self.combinedCategories
                )
            )
        } else {
            self.registrationDelegate?
                .notificationRegistrationFinished(
                    withAuthorizedSettings: settings,
                    categories: self.combinedCategories,
                    status: status
                )
        }
        #else
        if let onNotificationRegistrationFinished {
            onNotificationRegistrationFinished(
                NotificationRegistrationResult(
                    authorizedSettings: settings,
                    status: status
                )
            )
        } else {
            self.registrationDelegate?
                .notificationRegistrationFinished(
                    withAuthorizedSettings: settings,
                    status: status
                )
        }
        #endif
    }

    #if !os(watchOS)

    public func setBadgeNumber(_ newBadgeNumber: Int) async throws {
        try await self.badger.setBadgeNumber(newBadgeNumber)
        if self.autobadgeEnabled, privacyManager.isEnabled(.push) {
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
                    forKey: DefaultAirshipPush.badgeSettingsKey
                )

                if privacyManager.isEnabled(.push) {
                    self.channel.updateRegistration(forcefully: true)
                }
            }
        }

        get {
            return self.dataStore.bool(forKey: DefaultAirshipPush.badgeSettingsKey)
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
                forKey: DefaultAirshipPush.timeZoneSettingsKey
            )
        }

        get {
            let timeZoneName =
                self.dataStore.string(forKey: DefaultAirshipPush.timeZoneSettingsKey) ?? ""
            return NSTimeZone(name: timeZoneName) ?? NSTimeZone.default
                as NSTimeZone
        }
    }

    /// Enables/Disables quiet time
    public var quietTimeEnabled: Bool {
        set {
            self.dataStore.setBool(
                newValue,
                forKey: DefaultAirshipPush.quietTimeEnabledSettingsKey
            )
        }

        get {
            return self.dataStore.bool(forKey: DefaultAirshipPush.quietTimeEnabledSettingsKey)
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
            self.config.airshipConfig.requestAuthorizationToUseNotifications
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

        guard self.config.airshipConfig.requestAuthorizationToUseNotifications else {
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

            await self.notificationRegistrationFinished()
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
        _ payload: inout ChannelRegistrationPayload
    ) async {
        guard self.privacyManager.isEnabled(.push) else {
            return
        }

        await self.waitForDeviceTokenRegistration()

        guard self.privacyManager.isEnabled(.push) else {
            return
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
         & AirshipAuthorizedNotificationSettings.scheduledDelivery
            .rawValue > 0)
        payload.channel.iOSChannelSettings?.isTimeSensitive =
        (self.authorizedNotificationSettings.rawValue
         & AirshipAuthorizedNotificationSettings.timeSensitive.rawValue
         > 0)

        return
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
extension DefaultAirshipPush: InternalAirshipPush {
    
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

        if let onAPNSRegistrationFinished {
            onAPNSRegistrationFinished(.success(deviceToken: tokenString))
        } else {
            self.registrationDelegate?.apnsRegistrationSucceeded(
                withDeviceToken: deviceToken
            )
        }
    }

    public func didFailToRegisterForRemoteNotifications(_ error: any Error) {
        guard self.privacyManager.isEnabled(.push) else {
            return
        }

        if let onAPNSRegistrationFinished {
            onAPNSRegistrationFinished(.failure(error: error))
        } else {
            self.registrationDelegate?.apnsRegistrationFailedWithError(error)
        }
    }

    public func presentationOptionsForNotification(_ notification: UNNotification) async -> UNNotificationPresentationOptions {
        guard self.privacyManager.isEnabled(.push) else {
            return []
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
                    case DefaultAirshipPush.presentationOptionBadge:
                        options.insert(.badge)
                    case DefaultAirshipPush.presentationOptionAlert:
                        options.insert(.list)
                        options.insert(.banner)
                    case DefaultAirshipPush.presentationOptionSound:
                        options.insert(.sound)
                    case DefaultAirshipPush.presentationOptionList:
                        options.insert(.list)
                    case DefaultAirshipPush.presentationOptionBanner:
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
        
        if let onExtendPresentationOptions = self.onExtendPresentationOptions {
            options = await onExtendPresentationOptions(options, notification)
        } else if let delegate = self.pushNotificationDelegate {
            options = await delegate.extendPresentationOptions(options, notification: notification)
        }

        return options
    }

    #if !os(tvOS)

    public func didReceiveNotificationResponse(_ response: UNNotificationResponse) async {
        guard self.privacyManager.isEnabled(.push) else {
            return
        }

        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            self.launchNotificationResponse = response
        }

        self.notificationCenter.post(
            name: AirshipNotifications.ReceivedNotificationResponse.name,
            object: self,
            userInfo: [
                AirshipNotifications.ReceivedNotificationResponse.responseKey: response
            ]
        )

        if let onNotificationResponseReceived = self.onNotificationResponseReceived {
            await onNotificationResponseReceived(response)
        } else {
            await self.pushNotificationDelegate?.receivedNotificationResponse(response)
        }
    }

    #endif

    @MainActor
    public func didReceiveRemoteNotification(
        _ notification: [AnyHashable: Any],
        isForeground: Bool
    ) async -> any Sendable {

        guard self.privacyManager.isEnabled(.push) else {
            #if !os(watchOS)
            return UIBackgroundFetchResult.noData
            #else
            return WKBackgroundFetchResult.noData
            #endif
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
            if let onForegroundNotificationReceived = self.onForegroundNotificationReceived {
                await onForegroundNotificationReceived(notification)
            } else {
                await delegate?.receivedForegroundNotification(notification)
            }

            #if !os(watchOS)
            return UIBackgroundFetchResult.noData
            #else
            return WKBackgroundFetchResult.noData
            #endif
        } else {
            if let onBackgroundNotificationReceived = self.onBackgroundNotificationReceived {
                return await onBackgroundNotificationReceived(notification)
            } else if let result = await delegate?.receivedBackgroundNotification(notification) {
                return result
            } else {
                #if !os(watchOS)
                return UIBackgroundFetchResult.noData
                #else
                return WKBackgroundFetchResult.noData
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
            DefaultAirshipPush.ForegroundPresentationkey
        ]
        as? [String]

        if presentationOptions == nil {
            presentationOptions =
            notification.request.content.userInfo[
                DefaultAirshipPush.ForegroundPresentationLegacykey
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


extension DefaultAirshipPush: AirshipComponent {}


public extension AirshipNotifications {

    /// NSNotification info when a notification response is received.
    final class ReceivedNotificationResponse {

        /// NSNotification name.
        public static let name = NSNotification.Name(
            "com.urbanairship.push.received_notification_response"
        )

        /// NSNotification userInfo key to get the response dictionary.
        public static let responseKey: String = "response"
    }


    /// NSNotification info when a notification is received..
    final class RecievedNotification {

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
