// Copyright Airship and Contributors

import Testing
@_spi(AirshipInternal) import AirshipBasement

@testable import AirshipCore
import Combine
import Foundation
import UserNotifications
#if !os(watchOS)
import UIKit
#endif

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct AirshipPushTest {

    private static let validDeviceToken = "0123456789abcdef0123456789abcdef"

    private let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let channel = TestChannel()
    private let analtyics = TestAnalytics()
    private var permissionsManager: DefaultAirshipPermissionsManager!

    private let notificationCenter = AirshipNotificationCenter(notificationCenter: NotificationCenter())
    private let notificationRegistrar = TestNotificationRegistrar()
    private var apnsRegistrar: TestAPNSRegistrar!
    private let badger = TestBadger()
    private let registrationDelegate = TestRegistraitonDelegate()
    private var pushDelegate: TestPushNotificationDelegate!

    private var config = AirshipConfig()
    private var privacyManager: TestPrivacyManager!
    private var push: DefaultAirshipPush!
    private let serialQueue: AirshipAsyncSerialQueue = AirshipAsyncSerialQueue(priority: .high)

    init() async {
        self.pushDelegate = TestPushNotificationDelegate()
        self.apnsRegistrar = TestAPNSRegistrar()
        self.permissionsManager = DefaultAirshipPermissionsManager()
        self.privacyManager = TestPrivacyManager(
            dataStore: self.dataStore,
            config: .testConfig(),
            defaultEnabledFeatures: .all,
            notificationCenter: self.notificationCenter
        )

        self.push = createPush()
        await self.serialQueue.waitForCurrentOperations()
        self.channel.updateRegistrationCalled = false
    }

    @MainActor
    func createPush() -> DefaultAirshipPush {
        return DefaultAirshipPush(
            config: .testConfig(airshipConfig: self.config),
            dataStore: dataStore,
            channel: channel,
            analytics: analtyics,
            privacyManager: privacyManager,
            permissionsManager: permissionsManager,
            notificationCenter: notificationCenter,
            notificationRegistrar: notificationRegistrar,
            apnsRegistrar: apnsRegistrar,
            badger: badger,
            serialQueue: serialQueue
        )
    }

    @Test
    @MainActor
    func testBackgroundPushNotificationsEnabled() async throws {
        #expect(self.push.backgroundPushNotificationsEnabled)
        #expect(!self.channel.updateRegistrationCalled)

        self.push.backgroundPushNotificationsEnabled = false
        await self.serialQueue.waitForCurrentOperations()
        #expect(self.channel.updateRegistrationCalled)
    }

    @Test
    func testNotificationsPromptedAuthorizedStatus() async throws {
        #expect(!self.push.userPromptedForNotifications)

        self.notificationRegistrar.onCheckStatus = {
            return (.authorized, [])
        }

        let completed = AirshipTestExpectation(description: "Completed")
        let _ = await self.permissionsManager.requestPermission(.displayNotifications)
        completed.fulfill()


        await fulfillment(of: [completed], timeout: 10.0)
        #expect(self.push.userPromptedForNotifications)
    }

    @Test
    func testNotificationsPromptedDeniedStatus() async throws {
        #expect(!self.push.userPromptedForNotifications)

        self.notificationRegistrar.onCheckStatus = {
            return(.denied, [])
        }

        let completed = AirshipTestExpectation(description: "Completed")
        let _ = await self.permissionsManager.requestPermission(.displayNotifications)
        completed.fulfill()


        await fulfillment(of: [completed], timeout: 10.0)
        #expect(self.push.userPromptedForNotifications)
    }

    @Test
    func testNotificationsPromptedEphemeralStatus() async throws {
        #expect(!self.push.userPromptedForNotifications)

        self.notificationRegistrar.onCheckStatus = {
            return(.ephemeral, [])
        }

        let completed = AirshipTestExpectation(description: "Completed")
        let _ = await self.permissionsManager.requestPermission(.displayNotifications)
        completed.fulfill()

        await fulfillment(of: [completed], timeout: 10.0)
        #expect(!self.push.userPromptedForNotifications)
    }

    @Test
    func testNotificationsPromptedNotDeterminedStatus() async throws {
        #expect(!self.push.userPromptedForNotifications)

        self.notificationRegistrar.onCheckStatus = {
            return(.notDetermined, [])
        }

        let completed = AirshipTestExpectation(description: "Completed")
        let _ = await self.permissionsManager.requestPermission(.displayNotifications)
        completed.fulfill()

        await fulfillment(of: [completed], timeout: 10.0)
        #expect(!self.push.userPromptedForNotifications)
    }

    @Test
    @MainActor
    func testNotificationsStatusPropogation() async throws {
        #expect(!self.push.userPromptedForNotifications)

        self.notificationRegistrar.onCheckStatus = {
            return (.authorized, [.badge])
        }

        let completed = AirshipTestExpectation(description: "Completed")

        let _ = await self.permissionsManager.requestPermission(.displayNotifications)

        let cancellable = self.push.notificationStatusPublisher.sink { status in
            #expect(true == status.areNotificationsAllowed)
            completed.fulfill()
        }

        let status = await self.push.notificationStatus
        #expect(true == status.areNotificationsAllowed)

        await fulfillment(of: [completed], timeout: 10.0)
        #expect(self.push.userPromptedForNotifications)

        cancellable.cancel()
    }

    /// Test that once prompted always prompted
    @Test
    @MainActor
    func testNotificationsPromptedStaysPrompted() async throws {
        #expect(!self.push.userPromptedForNotifications)

        self.notificationRegistrar.onCheckStatus = {
            return(.authorized, [])
        }

        let completed = AirshipTestExpectation(description: "Completed")
        let _ = await self.permissionsManager.requestPermission(.displayNotifications)
        completed.fulfill()

        await fulfillment(of: [completed], timeout: 10.0)

        self.notificationRegistrar.onCheckStatus = {
            return(.notDetermined, [])
        }

        let completedAgain = AirshipTestExpectation(description: "Completed Again")
        _ = await self.permissionsManager.requestPermission(.displayNotifications)
        completedAgain.fulfill()


        await fulfillment(of: [completedAgain], timeout: 10.0)

        #expect(self.push.userPromptedForNotifications)
    }

    @Test
    func testUserPushNotificationsEnabled() async throws {
        self.push.notificationOptions = [.alert, .badge]
        self.push.requestExplicitPermissionWhenEphemeral = false
        await self.serialQueue.waitForCurrentOperations()

        // Make sure updates are called through permissions manager
        let permissionsManagerCalled = AirshipTestExpectation(
            description: "Permissions manager called"
        )
        self.permissionsManager.addRequestExtender(
            permission: .displayNotifications
        ) { _ in
            permissionsManagerCalled.fulfill()
        }

        let updated = AirshipTestExpectation(description: "Registration updated")
        self.notificationRegistrar.onUpdateRegistration = {
            options,
            skipIfEphemeral in
            #expect([.alert, .badge] == options)
            #expect(skipIfEphemeral)
            updated.fulfill()
        }

        self.push.userPushNotificationsEnabled = true
        await self.serialQueue.waitForCurrentOperations()
        await fulfillment(of: [permissionsManagerCalled, updated], timeout: 20.0)
    }

    @Test
    func testUserPushNotificationsDisabled() async throws {
        let enabled = AirshipTestExpectation(description: "Registration updated")
        self.notificationRegistrar.onUpdateRegistration = {
            options,
            skipIfEphemeral in
            #expect([.badge, .alert, .sound] == options)
            #expect(skipIfEphemeral)
            enabled.fulfill()
        }

        self.push.userPushNotificationsEnabled = true
        await fulfillment(of: [enabled], timeout: 10.0)

        let disabled = AirshipTestExpectation(description: "Registration updated")
        self.notificationRegistrar.onUpdateRegistration = {
            options,
            skipIfEphemeral in
            #expect([] == options)
            #expect(skipIfEphemeral)
            disabled.fulfill()
        }

        self.push.userPushNotificationsEnabled = false
        await fulfillment(of: [disabled], timeout: 10.0)
    }

    /// Test that we always ephemeral when disabling notifications
    @Test
    func testUserPushNotificationsSkipEphemeral() async throws {
        self.push.requestExplicitPermissionWhenEphemeral = false
        await self.serialQueue.waitForCurrentOperations()

        let enabled = AirshipTestExpectation(description: "Registration updated")
        self.notificationRegistrar.onUpdateRegistration = { options, skipIfEphemeral in
            #expect([.badge, .alert, .sound] == options)
            #expect(skipIfEphemeral)
            enabled.fulfill()
        }

        self.push.userPushNotificationsEnabled = true
        await self.serialQueue.waitForCurrentOperations()
        await fulfillment(of: [enabled], timeout: 10.0)

        let disabled = AirshipTestExpectation(description: "Registration updated")
        self.notificationRegistrar.onUpdateRegistration = { options, skipIfEphemeral in
            #expect([] == options)
            #expect(skipIfEphemeral)
            disabled.fulfill()
        }

        self.push.userPushNotificationsEnabled = false
        await self.serialQueue.waitForCurrentOperations()
        await fulfillment(of: [disabled], timeout: 10.0)
    }

    @Test
    mutating func testEnableUserNotificationsAppHandlingAuth() async throws {
        self.config.requestAuthorizationToUseNotifications = false
        self.push = createPush()

        self.permissionsManager.addRequestExtender(
            permission: .displayNotifications
        ) { _ in
            Issue.record("Should be skipped")
        }

        self.notificationRegistrar.onCheckStatus = {
            return(.authorized, [])
        }

        let success = await self.push.enableUserPushNotifications()
        #expect(success)
    }

    @Test
    func testEnableUserNotificationsAuthorized() async throws {
        // Make sure updates are called through permissions manager
        let permissionsManagerCalled = AirshipTestExpectation(
            description: "Permissions manager called"
        )
        self.permissionsManager.addRequestExtender(
            permission: .displayNotifications
        ) { _ in
            permissionsManagerCalled.fulfill()
        }

        self.push.notificationOptions = [.alert, .badge]
        self.push.requestExplicitPermissionWhenEphemeral = false
        await self.serialQueue.waitForCurrentOperations()

        self.notificationRegistrar.onCheckStatus = {
            return(.authorized, [])
        }

        let success = await self.push.enableUserPushNotifications()
        #expect(success)

        await fulfillment(of: [permissionsManagerCalled], timeout: 10.0)
    }

    @Test
    func testEnableUserNotificationsDenied() async throws {
        self.notificationRegistrar.onCheckStatus = {
            return(.denied, [])
        }

        let enabled = AirshipTestExpectation(description: "Enabled")
        let success = await self.push.enableUserPushNotifications()
        enabled.fulfill()
        #expect(!success)

        await fulfillment(of: [enabled], timeout: 10.0)
    }

    @Test
    func testSkipWhenEphemeralDisabled() async throws {
        let updated = AirshipTestExpectation(description: "Registration updated")

        self.push.notificationOptions = [.alert, .badge]
        self.push.requestExplicitPermissionWhenEphemeral = true
        await self.serialQueue.waitForCurrentOperations()

        self.notificationRegistrar.onUpdateRegistration = {
            options,
            skipIfEphemeral in
            #expect([.alert, .badge] == options)
            #expect(!skipIfEphemeral)
            updated.fulfill()
        }

        self.push.userPushNotificationsEnabled = true

        await fulfillment(of: [updated], timeout: 10.0)
    }

    @Test
    @MainActor
    func testDeviceToken() throws {
        push.didRegisterForRemoteNotifications(
            AirshipPushTest.validDeviceToken.hexData
        )
        #expect(AirshipPushTest.validDeviceToken == self.push.deviceToken)
    }

    @Test
    func testSetQuietTime() throws {
        self.push.setQuietTimeStartHour(
            12,
            startMinute: 30,
            endHour: 14,
            endMinute: 58
        )
        #expect(
            "12:30" ==
            self.push.quietTime?.startString
        )
        #expect(
            "14:58" ==
            self.push.quietTime?.endString
        )
        #expect(self.channel.updateRegistrationCalled)
        let expected = try QuietTimeSettings(startHour: 12, startMinute: 30, endHour: 14, endMinute: 58)
        #expect(expected == self.push.quietTime)
    }


    @Test
    func testSetQuietTimeInvalid() throws {
        #expect(self.push.quietTime == nil)

        self.push.setQuietTimeStartHour(
            25,
            startMinute: 30,
            endHour: 14,
            endMinute: 58
        )
        #expect(self.push.quietTime == nil)

        self.push.setQuietTimeStartHour(
            12,
            startMinute: 61,
            endHour: 14,
            endMinute: 58
        )
        #expect(self.push.quietTime == nil)
    }

    @Test
    func testSetTimeZone() throws {
        self.push.timeZone = NSTimeZone(abbreviation: "HST")
        // Timezone abbreviation strings vary across OS versions (e.g. iOS 26
        // reports "GMT-10" instead of "HST"), so assert on the stable UTC
        // offset instead. Hawaii does not observe DST, so this is constant.
        #expect(self.push.timeZone?.secondsFromGMT == -36000)
        self.push.timeZone = nil
        #expect(NSTimeZone.default as NSTimeZone == self.push.timeZone)
    }

    @Test
    @MainActor
    func testChannelPayloadRegistered() async throws {
        self.push.didRegisterForRemoteNotifications(
            AirshipPushTest.validDeviceToken.hexData
        )

        let payload = await self.channel.channelPayload

        #expect(AirshipPushTest.validDeviceToken == payload.channel.pushAddress)
        #expect(
            payload.channel.iOSChannelSettings?.isTimeSensitive == false
        )
        #expect(
            payload.channel.iOSChannelSettings?.isScheduledSummary == false
        )
    }

    @Test
    func testChannelPayloadNotRegistered() async throws {
        let payload = await self.channel.channelPayload

        #expect(payload.channel.pushAddress == nil)
        #expect(!payload.channel.isOptedIn)
        #expect(!payload.channel.isBackgroundEnabled)
        #expect(payload.channel.iOSChannelSettings?.quietTime == nil)
        #expect(payload.channel.iOSChannelSettings?.quietTimeTimeZone == nil)
        #expect(
            payload.channel.iOSChannelSettings?.isTimeSensitive == false
        )
        #expect(
            payload.channel.iOSChannelSettings?.isScheduledSummary == false
        )
        #expect(payload.channel.iOSChannelSettings?.badge == nil)
    }

    @Test
    @MainActor
    func testChannelPayloadNotificationsEnabled() async throws {
        self.push.didRegisterForRemoteNotifications(
            AirshipPushTest.validDeviceToken.hexData
        )
        apnsRegistrar.isRegisteredForRemoteNotifications = true
        apnsRegistrar.isRemoteNotificationBackgroundModeEnabled = true
        apnsRegistrar.isBackgroundRefreshStatusAvailable = true

        self.notificationRegistrar.onCheckStatus = {
            return(
                .authorized,
                [.timeSensitive, .scheduledDelivery, .alert]
            )
        }

        let enabled = AirshipTestExpectation(description: "Registration updated")
        let status = await self.permissionsManager.requestPermission(
            .displayNotifications,
            enableAirshipUsageOnGrant: true
        )
        enabled.fulfill()
        #expect(.granted == status)

        await fulfillment(of: [enabled], timeout: 10.0)

        let payload = await self.channel.channelPayload

        #expect(AirshipPushTest.validDeviceToken == payload.channel.pushAddress)
        #expect(payload.channel.isOptedIn)
        #expect(payload.channel.isBackgroundEnabled)
        #expect(
            payload.channel.iOSChannelSettings?.isTimeSensitive == true
        )
        #expect(
            payload.channel.iOSChannelSettings?.isScheduledSummary == true
        )
    }

    @Test
    func testChannelPayloadQuietTime() async throws {
        self.push.quietTimeEnabled = true
        self.push.setQuietTimeStartHour(
            1,
            startMinute: 30,
            endHour: 2,
            endMinute: 30
        )
        self.push.timeZone = NSTimeZone(abbreviation: "EDT")

        let payload = await self.channel.channelPayload

        #expect(
            "01:30" ==
            payload.channel.iOSChannelSettings?.quietTime?.start
        )
        #expect(
            "02:30" ==
            payload.channel.iOSChannelSettings?.quietTime?.end
        )
        #expect(
            "America/New_York" ==
            payload.channel.iOSChannelSettings?.quietTimeTimeZone
        )
    }

    @Test
    func testChannelPayloadQuietTimeDisabled() async throws {
        self.push.quietTimeEnabled = false
        self.push.setQuietTimeStartHour(
            1,
            startMinute: 30,
            endHour: 2,
            endMinute: 30
        )
        self.push.timeZone = NSTimeZone(abbreviation: "EDT")

        let payload = await self.channel.channelPayload

        #expect(payload.channel.iOSChannelSettings?.quietTime == nil)
        #expect(payload.channel.iOSChannelSettings?.quietTimeTimeZone == nil)
    }

    @Test
    @MainActor
    func testChannelPayloadAutoBadge() async throws {
        self.push.autobadgeEnabled = true
        try await self.push.setBadgeNumber(10)

        let payload = await self.channel.channelPayload

        #expect(10 == payload.channel.iOSChannelSettings?.badge)
    }

    @Test
    func testAnalyticsHeadersOptedOut() async throws {
        let expected = [
            "X-UA-Channel-Opted-In": "false",
            "X-UA-Notification-Prompted": "false",
            "X-UA-Channel-Background-Enabled": "false",
        ]
        let headers = await self.analtyics.headers
        #expect(expected == headers)
    }

    @Test
    @MainActor
    func testAnalyticsHeadersOptedIn() async throws {
        self.push.didRegisterForRemoteNotifications(
            AirshipPushTest.validDeviceToken.hexData
        )
        apnsRegistrar.isRegisteredForRemoteNotifications = true
        apnsRegistrar.isRemoteNotificationBackgroundModeEnabled = true
        apnsRegistrar.isBackgroundRefreshStatusAvailable = true

        self.notificationRegistrar.onCheckStatus = {
            return(
                .authorized,
                [.timeSensitive, .scheduledDelivery, .alert]
            )
        }

        let enabled = AirshipTestExpectation(description: "Registration updated")
        let status = await self.permissionsManager.requestPermission(
            .displayNotifications,
            enableAirshipUsageOnGrant: true
        )
        enabled.fulfill()
        #expect(.granted == status)
        await fulfillment(of: [enabled], timeout: 10.0)

        let expected = [
            "X-UA-Channel-Opted-In": "true",
            "X-UA-Notification-Prompted": "true",
            "X-UA-Channel-Background-Enabled": "true",
            "X-UA-Push-Address": AirshipPushTest.validDeviceToken,
        ]

        let headers = await self.analtyics.headers
        #expect(expected == headers)
    }

    @Test
    func testAnalyticsHeadersPushDisabled() async throws {
        self.push.didRegisterForRemoteNotifications(
            AirshipPushTest.validDeviceToken.hexData
        )
        self.privacyManager.disableFeatures(.push)
        let expected = [
            "X-UA-Channel-Opted-In": "false",
            "X-UA-Channel-Background-Enabled": "false",
        ]

        let headers = await self.analtyics.headers
        #expect(expected == headers)
    }

    @Test
    @MainActor
    func testDefaultNotificationCategories() throws {
        let defaultCategories = NotificationCategories.defaultCategories()
        #expect(defaultCategories == notificationRegistrar.categories)
        #expect(defaultCategories == self.push.combinedCategories)
    }

    @Test
    @MainActor
    func testNotificationCategories() throws {
        let defaultCategories = NotificationCategories.defaultCategories()
        let customCategory = UNNotificationCategory(
            identifier: "something",
            actions: [],
            intentIdentifiers: ["intents"]
        )
        let combined = Set(defaultCategories).union([customCategory])

        self.push.customCategories = Set([customCategory])
        #expect(combined == notificationRegistrar.categories)
    }

    @Test
    @MainActor
    func testRequireAuthorizationForDefaultCategories() throws {
        self.push.requireAuthorizationForDefaultCategories = true
        let defaultCategories = NotificationCategories.defaultCategories(
            withRequireAuth: true
        )
        #expect(defaultCategories == notificationRegistrar.categories)
        #expect(defaultCategories == self.push.combinedCategories)
    }

    @Test
    @MainActor
    func testBadge() async throws {
        try await self.push.setBadgeNumber(100)
        #expect(100 == self.badger.applicationIconBadgeNumber)
    }

    @Test
    @MainActor
    func testAutoBadge() async throws {
        self.push.autobadgeEnabled = false
        try await self.push.setBadgeNumber(10)
        #expect(!self.channel.updateRegistrationCalled)

        self.push.autobadgeEnabled = true
        #expect(self.channel.updateRegistrationCalled)

        self.channel.updateRegistrationCalled = false
        try await self.push.setBadgeNumber(1)
        #expect(self.channel.updateRegistrationCalled)

        self.channel.updateRegistrationCalled = false
        self.push.autobadgeEnabled = false
        #expect(self.channel.updateRegistrationCalled)
    }

    @Test
    @MainActor
    func testResetBadge() async throws {
        try await self.push.setBadgeNumber(1000)
        #expect(1000 == self.push.badgeNumber)

        try await self.push.resetBadge()
        #expect(0 == self.push.badgeNumber)
        #expect(0 == self.badger.applicationIconBadgeNumber)
    }

    @Test
    func testActiveChecksRegistration() async  {
        self.notificationRegistrar.onCheckStatus = {
            return (.authorized, [.alert])
        }

        self.notificationCenter.post(
            name: AppStateTracker.didBecomeActiveNotification,
            object: nil
        )

        await self.serialQueue.waitForCurrentOperations()

        #expect(.authorized == self.push.authorizationStatus)
        let settings = self.push.authorizedNotificationSettings
        #expect([.alert] == settings)
        #expect(self.push.userPromptedForNotifications)
    }

    @Test
    func testAuthorizedStatusUpdatesChannelRegistration() async {
        self.notificationRegistrar.onCheckStatus = {
            return(.authorized, [.alert])
        }

        self.notificationCenter.post(
            name: AppStateTracker.didBecomeActiveNotification,
            object: nil
        )

        await self.serialQueue.waitForCurrentOperations()
        #expect(self.channel.updateRegistrationCalled)
    }

    @Test
    func testDefaultOptions() {
        #expect([.alert, .badge, .sound] == self.push.notificationOptions)
    }

    @Test
    func testDefaultOptionsProvisional() async {
        self.notificationRegistrar.onCheckStatus = {
            return(.provisional, [])
        }

        let completed = AirshipTestExpectation(description: "Completed")
        let _ = await self.permissionsManager.requestPermission(.displayNotifications)
        completed.fulfill()


        self.push.userPushNotificationsEnabled = true
        await fulfillment(of: [completed], timeout: 10.0)

        #expect(
            [.alert, .badge, .sound, .provisional] ==
            self.push.notificationOptions
        )
    }

    @Test
    @MainActor
    mutating func testCategoriesWhenAppIsHandlingAuthorization() {
        self.notificationRegistrar.categories = nil
        self.config.requestAuthorizationToUseNotifications = false
        self.push = createPush()

        let customCategory = UNNotificationCategory(
            identifier: "something",
            actions: [],
            intentIdentifiers: ["intents"]
        )
        self.push.customCategories = Set([customCategory])

        #expect(self.notificationRegistrar.categories == nil)
    }

    @Test
    @MainActor
    mutating func testPermissionsDelgateWhenAppIsHandlingAuthorization() {
        #expect(
            self.permissionsManager.configuredPermissions.contains(
                .displayNotifications
            )
        )
        self.permissionsManager.setDelegate(
            nil,
            permission: .displayNotifications
        )

        #expect(
            !self.permissionsManager.configuredPermissions.contains(
                .displayNotifications
            )
        )
        self.config.requestAuthorizationToUseNotifications = false
        self.push = createPush()

        #expect(
            self.permissionsManager.configuredPermissions.contains(
                .displayNotifications
            )
        )
    }

    @Test
    @MainActor
    func testForwardNotificationRegistrationFinished() async {
        self.push.registrationDelegate = self.registrationDelegate

        self.notificationRegistrar.onCheckStatus = {
            return(.provisional, [.badge])
        }

        let called = AirshipTestExpectation(description: "Delegate called")
        self.registrationDelegate.onNotificationRegistrationFinished = {
            settings,
            categories,
            status in
            #expect([.badge] == settings)
            #expect(self.push.combinedCategories == categories)
            #expect(.provisional == status)
            called.fulfill()
        }

        self.push.userPushNotificationsEnabled = true
        await fulfillment(of: [called], timeout: 10.0)
    }

    @Test
    @MainActor
    func testForwardAuthorizedSettingsChanges() async {
        self.push.registrationDelegate = self.registrationDelegate
        self.notificationRegistrar.onCheckStatus = {
            return(.provisional, [.alert])
        }

        let called = AirshipTestExpectation(description: "Delegate called")
        self.registrationDelegate.onNotificationAuthorizedSettingsDidChange = {
            settings in
            #expect([.alert] == settings)
            called.fulfill()
        }

        self.push.userPushNotificationsEnabled = true
        await fulfillment(of: [called], timeout: 10.0)
    }

    @Test
    @MainActor
    func testForwardAuthorizedSettingsChangesForeground() async {
        self.push.registrationDelegate = self.registrationDelegate
        self.notificationRegistrar.onCheckStatus = {
            return(.provisional, [.badge])
        }

        let called = AirshipTestExpectation(description: "Delegate called")
        self.registrationDelegate.onNotificationAuthorizedSettingsDidChange = {
            settings in
            #expect([.badge] == settings)
            called.fulfill()
        }

        self.notificationCenter.post(
            name: AppStateTracker.didBecomeActiveNotification,
            object: nil
        )

        await fulfillment(of: [called], timeout: 10.0)
    }

    @Test
    @MainActor
    func testForwardAPNSRegistrationSucceeded() async {
        let expectedToken = AirshipPushTest.validDeviceToken.hexData

        self.push.registrationDelegate = self.registrationDelegate

        let called = AirshipTestExpectation(description: "Delegate called")
        self.registrationDelegate.onAPNSRegistrationSucceeded = { token in
            #expect(expectedToken == token)
            called.fulfill()
        }

        self.push.didRegisterForRemoteNotifications(expectedToken)
        await fulfillment(of: [called], timeout: 10.0)
    }

    @Test
    @MainActor
    func testForwardAPNSRegistrationFailed() async {
        let expectedError = AirshipErrors.error("something")

        self.push.registrationDelegate = self.registrationDelegate

        let called = AirshipTestExpectation(description: "Delegate called")
        self.registrationDelegate.onAPNSRegistrationFailed = { error in
            #expect(
                expectedError.localizedDescription ==
                error.localizedDescription
            )
            called.fulfill()
        }

        self.push.didFailToRegisterForRemoteNotifications(expectedError)
        await fulfillment(of: [called], timeout: 10.0)
    }

    @Test
    @MainActor
    func testReceivedForegroundNotification() async {
        let expected = ["cool": "payload"]

        let result = await self.push.didReceiveRemoteNotification(
            expected,
            isForeground: true
        )

        #expect(UABackgroundFetchResult.noData == result)
    }

    @Test
    @MainActor
    func testForwardReceivedForegroundNotification() async {
        let expected = ["cool": "payload"]
        self.push.pushNotificationDelegate = self.pushDelegate

        self.pushDelegate.onReceivedForegroundNotification = {
            notificaiton in
            #expect(
                expected as NSDictionary ==
                notificaiton as NSDictionary
            )
        }

        let result = await self.push.didReceiveRemoteNotification(expected, isForeground: true)

        #expect(UABackgroundFetchResult.noData == result)
    }

    @Test
    @MainActor
    func testReceivedBackgroundNotification() async {
        let expected = ["cool": "payload"]

        let result = await self.push.didReceiveRemoteNotification(
            expected,
            isForeground: false
        )

        #expect(UABackgroundFetchResult.noData == result)
    }

    @Test
    @MainActor
    func testForwardReceivedBackgroundNotification() async {
        let expected = ["cool": "payload"]
        self.push.pushNotificationDelegate = self.pushDelegate

        self.pushDelegate.onReceivedBackgroundNotification = {
            notificaiton in
            #expect(
                expected as NSDictionary ==
                notificaiton as NSDictionary
            )
            return .newData
        }

        let result = await self.push.didReceiveRemoteNotification(
            expected,
            isForeground: false
        )

        #expect(UABackgroundFetchResult.newData == result)
    }

    @Test
    @MainActor
    func testOptionsPermissionDelegate() async {
        self.push.userPushNotificationsEnabled = false
        self.push.notificationOptions = .alert

        let updated = AirshipTestExpectation(description: "Registration updated")
        self.notificationRegistrar.onUpdateRegistration = {
            options,
            skipIfEphemeral in
            #expect(skipIfEphemeral)
            if options == [.alert] {
                updated.fulfill()
            }
        }

        let completionHandlerCalled = AirshipTestExpectation(
            description: "Completion handler called"
        )
        let _ = await self.permissionsManager.requestPermission(.displayNotifications)
        completionHandlerCalled.fulfill()

        await fulfillment(of: [updated, completionHandlerCalled], timeout: 10)
    }

    @Test
    @MainActor
    func testNotificationStatus() async {
        self.push.didRegisterForRemoteNotifications(
            AirshipPushTest.validDeviceToken.hexData
        )
        self.push.userPushNotificationsEnabled = true

        self.notificationRegistrar.onCheckStatus = {
            return (.authorized, [.alert])
        }

        self.apnsRegistrar.isRegisteredForRemoteNotifications = true

        self.privacyManager.enabledFeatures = .push

        let status = await self.push.notificationStatus
        #expect(
            AirshipNotificationStatus(
                isUserNotificationsEnabled: true,
                areNotificationsAllowed: true,
                isPushPrivacyFeatureEnabled: true,
                isPushTokenRegistered: true,
                displayNotificationStatus: .granted
            ) ==
            status
        )
    }

    @Test
    @MainActor
    func testNotificationStatusNoTokenRegistration() async {
        self.push.didRegisterForRemoteNotifications(
            AirshipPushTest.validDeviceToken.hexData
        )

        var status = await self.push.notificationStatus
        #expect(
            AirshipNotificationStatus(
                isUserNotificationsEnabled: false,
                areNotificationsAllowed: false,
                isPushPrivacyFeatureEnabled: true,
                isPushTokenRegistered: false,
                displayNotificationStatus: .notDetermined
            ) ==
            status
        )

        self.apnsRegistrar.isRegisteredForRemoteNotifications = true

        status = await self.push.notificationStatus
        #expect(
            AirshipNotificationStatus(
                isUserNotificationsEnabled: false,
                areNotificationsAllowed: false,
                isPushPrivacyFeatureEnabled: true,
                isPushTokenRegistered: true,
                displayNotificationStatus: .notDetermined
            ) ==
            status
        )
    }


    @Test
    @MainActor
    func testNotificationStatusAllowed() async {
        self.notificationRegistrar.onCheckStatus = {
            return (.notDetermined, [.alert])
        }

        var status = await self.push.notificationStatus
        #expect(
            AirshipNotificationStatus(
                isUserNotificationsEnabled: false,
                areNotificationsAllowed: false,
                isPushPrivacyFeatureEnabled: true,
                isPushTokenRegistered: false,
                displayNotificationStatus: .notDetermined
            ) ==
            status
        )

        self.notificationRegistrar.onCheckStatus = {
            return (.authorized, [.alert])
        }

        status = await self.push.notificationStatus
        #expect(
            AirshipNotificationStatus(
                isUserNotificationsEnabled: false,
                areNotificationsAllowed: true,
                isPushPrivacyFeatureEnabled: true,
                isPushTokenRegistered: false,
                displayNotificationStatus: .granted
            ) ==
            status
        )
    }

    @Test
    @MainActor
    func testChannelRegistrationWaitsForToken() async {
        apnsRegistrar.isRegisteredForRemoteNotifications = true

        let startedCRATask = AirshipTestExpectation(description: "Started CRA")

        let push = self.push!
        let channel = self.channel

        Task {
            await fulfillment(of: [startedCRATask])
            push.didRegisterForRemoteNotifications(
                AirshipPushTest.validDeviceToken.hexData
            )
        }

        let payload = await Task {
            Task { @MainActor in
                try await Task.sleep(for: .milliseconds(100))
                startedCRATask.fulfill()
            }
            return await channel.channelPayload
        }.value


        #expect(payload.channel.pushAddress != nil)
    }

    @Test
    @MainActor
    func testAPNSRegistrationFinishedDelegateFallbackSuccess() async {
        let expectedToken = "some-token"
        let delegate = TestRegistraitonDelegate()
        let expectation = AirshipTestExpectation(description: "Delegate called")
        delegate.onAPNSRegistrationSucceeded = { tokenData in
            #expect(expectedToken.hexData == tokenData)
            expectation.fulfill()
        }

        self.push.registrationDelegate = delegate
        self.push.onAPNSRegistrationFinished = nil

        self.push.didRegisterForRemoteNotifications(expectedToken.hexData)
        await fulfillment(of: [expectation], timeout: 10.0)
    }

    @Test
    @MainActor
    func testAPNSRegistrationFinishedDelegateFallbackFailure() async {
        let expectedError = AirshipErrors.error("some error")
        let delegate = TestRegistraitonDelegate()
        let expectation = AirshipTestExpectation(description: "Delegate called")
        delegate.onAPNSRegistrationFailed = { error in
            #expect(expectedError.localizedDescription == error.localizedDescription)
            expectation.fulfill()
        }

        self.push.registrationDelegate = delegate
        self.push.onAPNSRegistrationFinished = nil

        self.push.didFailToRegisterForRemoteNotifications(expectedError)
        await fulfillment(of: [expectation], timeout: 10.0)
    }

    @Test
    @MainActor
    func testNotificationRegistrationFinishedCallback() async {
        let expectation = AirshipTestExpectation(description: "Callback called")
        self.notificationRegistrar.onCheckStatus = {
            return (.authorized, [.alert])
        }

        self.push.onNotificationRegistrationFinished = { result in
            #expect(.authorized == result.status)
            #expect([.alert] == result.authorizedSettings)
            #expect(self.push.combinedCategories == result.categories)
            expectation.fulfill()
        }

        let _ = await self.permissionsManager.requestPermission(.displayNotifications)
        await fulfillment(of: [expectation], timeout: 10.0)
    }

    @Test
    @MainActor
    func testNotificationRegistrationFinishedDelegateFallback() async {
        let delegate = TestRegistraitonDelegate()
        let expectation = AirshipTestExpectation(description: "Delegate called")
        self.notificationRegistrar.onCheckStatus = {
            return (.authorized, [.alert])
        }

        delegate.onNotificationRegistrationFinished = { settings, categories, status in
            #expect(.authorized == status)
            #expect([.alert] == settings)
            #expect(self.push.combinedCategories == categories)
            expectation.fulfill()
        }
        self.push.registrationDelegate = delegate
        self.push.onNotificationRegistrationFinished = nil

        let _ = await self.permissionsManager.requestPermission(.displayNotifications)
        await fulfillment(of: [expectation], timeout: 10.0)
    }

    @Test
    @MainActor
    func testAuthorizedSettingsDidChangeCallback() async {
        let expectation = AirshipTestExpectation(description: "Callback called")
        self.notificationRegistrar.onCheckStatus = {
            return (.authorized, [.sound])
        }

        self.push.onNotificationAuthorizedSettingsDidChange = { settings in
            #expect([.sound] == settings)
            expectation.fulfill()
        }

        let _ = await self.permissionsManager.requestPermission(.displayNotifications)
        await fulfillment(of: [expectation], timeout: 10.0)
    }

    @Test
    @MainActor
    func testAuthorizedSettingsDidChangeDelegateFallback() async {
        let delegate = TestRegistraitonDelegate()
        let expectation = AirshipTestExpectation(description: "Delegate called")
        self.notificationRegistrar.onCheckStatus = {
            return (.authorized, [.sound])
        }

        delegate.onNotificationAuthorizedSettingsDidChange = { settings in
            #expect([.sound] == settings)
            expectation.fulfill()
        }
        self.push.registrationDelegate = delegate
        self.push.onNotificationAuthorizedSettingsDidChange = nil

        let _ = await self.permissionsManager.requestPermission(.displayNotifications)
        await fulfillment(of: [expectation], timeout: 10.0)
    }
}

extension String {
    var hexData: Data {
        let chars = Array(self)
        let bytes = stride(from: 0, to: chars.count, by: 2)
            .compactMap { UInt8("\(chars[$0])\(chars[$0 + 1])", radix: 16) }
        return Data(bytes)
    }
}

@MainActor
class TestPushNotificationDelegate: PushNotificationDelegate {
    func extendPresentationOptions(_ options: UNNotificationPresentationOptions, notification: UNNotification) async -> UNNotificationPresentationOptions {
        return self.onExtend?(options, notification) ?? options
    }
    
    var onReceivedForegroundNotification:
        (([AnyHashable: Any]) -> Void)?
    var onReceivedBackgroundNotification:
        (([AnyHashable: Any]) -> UIBackgroundFetchResult)?
    var onReceivedNotificationResponse: ((UNNotificationResponse) -> Void)?
    var onExtend:
        (
            (UNNotificationPresentationOptions, UNNotification) ->
                UNNotificationPresentationOptions
        )?

    func receivedForegroundNotification(_ userInfo: [AnyHashable: Any]) async {
        guard let block = onReceivedForegroundNotification else {
            return
        }
        
        block(userInfo)
    }

    func receivedBackgroundNotification(
        _ userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        guard let block = onReceivedBackgroundNotification else {
            return .noData
        }
        return block(userInfo)
    }

    func receivedNotificationResponse(_ notificationResponse: UNNotificationResponse) async {
        guard let block = onReceivedNotificationResponse else {
            return
        }
        
        block(notificationResponse)
    }
}

class TestRegistraitonDelegate: NSObject, RegistrationDelegate {
    func notificationRegistrationFinished(withAuthorizedSettings authorizedSettings: AirshipAuthorizedNotificationSettings, status: UNAuthorizationStatus) {}
    

    var onNotificationRegistrationFinished:
        (
            (
                AirshipAuthorizedNotificationSettings, Set<UNNotificationCategory>,
                UNAuthorizationStatus
            ) -> Void
        )?
    var onNotificationAuthorizedSettingsDidChange:
        ((AirshipAuthorizedNotificationSettings) -> Void)?
    var onAPNSRegistrationSucceeded: ((Data) -> Void)?
    var onAPNSRegistrationFailed: ((Error) -> Void)?

    func notificationRegistrationFinished(
        withAuthorizedSettings authorizedSettings:
            AirshipAuthorizedNotificationSettings,
        categories: Set<UNNotificationCategory>,
        status: UNAuthorizationStatus
    ) {
        self.onNotificationRegistrationFinished?(
            authorizedSettings,
            categories,
            status
        )
    }

    func notificationAuthorizedSettingsDidChange(
        _ authorizedSettings: AirshipAuthorizedNotificationSettings
    ) {
        self.onNotificationAuthorizedSettingsDidChange?(authorizedSettings)
    }

    func apnsRegistrationSucceeded(withDeviceToken deviceToken: Data) {
        self.onAPNSRegistrationSucceeded?(deviceToken)
    }

    func apnsRegistrationFailedWithError(_ error: Error) {
        self.onAPNSRegistrationFailed?(error)
    }
}

final class TestNotificationRegistrar: NotificationRegistrar, @unchecked Sendable {
    var categories: Set<UNNotificationCategory>?
    var onCheckStatus:
        (() -> (UNAuthorizationStatus, AirshipAuthorizedNotificationSettings))?
    var onUpdateRegistration:
        ((UNAuthorizationOptions, Bool) -> Void)?

    func setCategories(_ categories: Set<UNNotificationCategory>) {
        self.categories = categories
    }

    func checkStatus() async -> (UNAuthorizationStatus, AirshipAuthorizedNotificationSettings) {
        guard let callback = self.onCheckStatus else {
            return(.notDetermined, [])
        }
        return callback()
    }

    func updateRegistration(
        options: UNAuthorizationOptions,
        skipIfEphemeral: Bool
    ) async -> Void {

        guard let callback = self.onUpdateRegistration else {
            return
        }
        callback(options, skipIfEphemeral)
    }
}

final class TestAPNSRegistrar: APNSRegistrar, @unchecked Sendable {
    var isRegisteredForRemoteNotifications: Bool = false
    var isBackgroundRefreshStatusAvailable: Bool = false
    var isRemoteNotificationBackgroundModeEnabled: Bool = false
    var registerForRemoteNotificationsCalled: Bool?

    func registerForRemoteNotifications() {
        registerForRemoteNotificationsCalled = true
    }
}

final class TestBadger: BadgerProtocol, @unchecked Sendable {
    var applicationIconBadgeNumber: Int = 0

    func setBadgeNumber(_ newBadgeNumber: Int) async throws {
        applicationIconBadgeNumber = newBadgeNumber
    }

    var badgeNumber: Int { return applicationIconBadgeNumber }
}
