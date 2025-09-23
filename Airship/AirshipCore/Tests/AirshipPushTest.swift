// Copyright Airship and Contributors

import XCTest

@testable import AirshipCore
import Combine

class AirshipPushTest: XCTestCase {

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
    private var serialQueue: AirshipAsyncSerialQueue = AirshipAsyncSerialQueue(priority: .high)

    override func setUp() async throws {
        self.pushDelegate = await TestPushNotificationDelegate()
        self.apnsRegistrar = await TestAPNSRegistrar()
        self.permissionsManager = await DefaultAirshipPermissionsManager()
        self.privacyManager = TestPrivacyManager(
            dataStore: self.dataStore,
            config: .testConfig(),
            defaultEnabledFeatures: .all,
            notificationCenter: self.notificationCenter
        )

        self.push = await createPush()
        await self.serialQueue.waitForCurrentOperations()
        self.channel.updateRegistrationCalled = false
    }

    override func tearDown() async throws {
        self.serialQueue.stop()
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

    @MainActor
    func testBackgroundPushNotificationsEnabled() async throws {
        XCTAssertTrue(self.push.backgroundPushNotificationsEnabled)
        XCTAssertFalse(self.channel.updateRegistrationCalled)

        self.push.backgroundPushNotificationsEnabled = false
        await self.serialQueue.waitForCurrentOperations()
        XCTAssertTrue(self.channel.updateRegistrationCalled)
    }

    func testNotificationsPromptedAuthorizedStatus() async throws {
        XCTAssertFalse(self.push.userPromptedForNotifications)

        self.notificationRegistrar.onCheckStatus = {
            return (.authorized, [])
        }

        let completed = self.expectation(description: "Completed")
        let _ = await self.permissionsManager.requestPermission(.displayNotifications)
        completed.fulfill()


        await self.fulfillment(of: [completed], timeout: 10.0)
        XCTAssertTrue(self.push.userPromptedForNotifications)
    }

    func testNotificationsPromptedDeniedStatus() async throws {
        XCTAssertFalse(self.push.userPromptedForNotifications)

        self.notificationRegistrar.onCheckStatus = {
            return(.denied, [])
        }

        let completed = self.expectation(description: "Completed")
        let _ = await self.permissionsManager.requestPermission(.displayNotifications)
        completed.fulfill()


        await self.fulfillment(of: [completed], timeout: 10.0)
        XCTAssertTrue(self.push.userPromptedForNotifications)
    }

    func testNotificationsPromptedEphemeralStatus() async throws {
        XCTAssertFalse(self.push.userPromptedForNotifications)

        self.notificationRegistrar.onCheckStatus = {
            return(.ephemeral, [])
        }

        let completed = self.expectation(description: "Completed")
        let _ = await self.permissionsManager.requestPermission(.displayNotifications)
        completed.fulfill()

        await self.fulfillment(of: [completed], timeout: 10.0)
        XCTAssertFalse(self.push.userPromptedForNotifications)
    }

    func testNotificationsPromptedNotDeterminedStatus() async throws {
        XCTAssertFalse(self.push.userPromptedForNotifications)

        self.notificationRegistrar.onCheckStatus = {
            return(.notDetermined, [])
        }

        let completed = self.expectation(description: "Completed")
        let _ = await self.permissionsManager.requestPermission(.displayNotifications)
        completed.fulfill()

        await self.fulfillment(of: [completed], timeout: 10.0)
        XCTAssertFalse(self.push.userPromptedForNotifications)
    }

    @MainActor
    func testNotificationsStatusPropogation() async throws {
        XCTAssertFalse(self.push.userPromptedForNotifications)

        self.notificationRegistrar.onCheckStatus = {
            return (.authorized, [.badge])
        }

        let completed = self.expectation(description: "Completed")

        let _ = await self.permissionsManager.requestPermission(.displayNotifications)

        let cancellable = self.push.notificationStatusPublisher.sink { status in
            XCTAssertEqual(true, status.areNotificationsAllowed)
            completed.fulfill()
        }

        let status = await self.push.notificationStatus
        XCTAssertEqual(true, status.areNotificationsAllowed)

        await self.fulfillment(of: [completed], timeout: 10.0)
        XCTAssertTrue(self.push.userPromptedForNotifications)

        cancellable.cancel()
    }

    /// Test that once prompted always prompted
    @MainActor
    func testNotificationsPromptedStaysPrompted() async throws {
        XCTAssertFalse(self.push.userPromptedForNotifications)

        self.notificationRegistrar.onCheckStatus = {
            return(.authorized, [])
        }

        let completed = self.expectation(description: "Completed")
        let _ = await self.permissionsManager.requestPermission(.displayNotifications)
        completed.fulfill()

        await self.fulfillment(of: [completed], timeout: 10.0)

        self.notificationRegistrar.onCheckStatus = {
            return(.notDetermined, [])
        }

        let completedAgain = self.expectation(description: "Completed Again")
        _ = await self.permissionsManager.requestPermission(.displayNotifications)
        completedAgain.fulfill()


        await self.fulfillment(of: [completedAgain], timeout: 10.0)

        XCTAssertTrue(self.push.userPromptedForNotifications)
    }

    func testUserPushNotificationsEnabled() async throws {
        self.push.notificationOptions = [.alert, .badge]
        self.push.requestExplicitPermissionWhenEphemeral = false
        await self.serialQueue.waitForCurrentOperations()

        // Make sure updates are called through permissions manager
        let permissionsManagerCalled = self.expectation(
            description: "Permissions manager called"
        )
        self.permissionsManager.addRequestExtender(
            permission: .displayNotifications
        ) { _ in
            permissionsManagerCalled.fulfill()
        }

        let updated = self.expectation(description: "Registration updated")
        self.notificationRegistrar.onUpdateRegistration = {
            options,
            skipIfEphemeral in
            XCTAssertEqual([.alert, .badge], options)
            XCTAssertTrue(skipIfEphemeral)
            updated.fulfill()
        }

        self.push.userPushNotificationsEnabled = true
        await self.serialQueue.waitForCurrentOperations()
        await self.fulfillment(of: [permissionsManagerCalled, updated], timeout: 20.0)
    }

    func testUserPushNotificationsDisabled() async throws {
        let enabled = self.expectation(description: "Registration updated")
        self.notificationRegistrar.onUpdateRegistration = {
            options,
            skipIfEphemeral in
            XCTAssertEqual([.badge, .alert, .sound], options)
            XCTAssertTrue(skipIfEphemeral)
            enabled.fulfill()
        }

        self.push.userPushNotificationsEnabled = true
        await self.fulfillment(of: [enabled], timeout: 10.0)

        let disabled = self.expectation(description: "Registration updated")
        self.notificationRegistrar.onUpdateRegistration = {
            options,
            skipIfEphemeral in
            XCTAssertEqual([], options)
            XCTAssertTrue(skipIfEphemeral)
            disabled.fulfill()
        }

        self.push.userPushNotificationsEnabled = false
        await self.fulfillment(of: [disabled], timeout: 10.0)
    }

    /// Test that we always ephemeral when disabling notifications
    func testUserPushNotificationsSkipEphemeral() async throws {
        self.push.requestExplicitPermissionWhenEphemeral = false
        await self.serialQueue.waitForCurrentOperations()

        let enabled = self.expectation(description: "Registration updated")
        self.notificationRegistrar.onUpdateRegistration = { options, skipIfEphemeral in
            XCTAssertEqual([.badge, .alert, .sound], options)
            XCTAssertTrue(skipIfEphemeral)
            enabled.fulfill()
        }

        self.push.userPushNotificationsEnabled = true
        await self.serialQueue.waitForCurrentOperations()
        await self.fulfillment(of: [enabled], timeout: 10.0)

        let disabled = self.expectation(description: "Registration updated")
        self.notificationRegistrar.onUpdateRegistration = { options, skipIfEphemeral in
            XCTAssertEqual([], options)
            XCTAssertTrue(skipIfEphemeral)
            disabled.fulfill()
        }

        self.push.userPushNotificationsEnabled = false
        await self.serialQueue.waitForCurrentOperations()
        await self.fulfillment(of: [disabled], timeout: 10.0)
    }

    func testEnableUserNotificationsAppHandlingAuth() async throws {
        self.config.requestAuthorizationToUseNotifications = false
        self.push = await createPush()

        self.permissionsManager.addRequestExtender(
            permission: .displayNotifications
        ) { _ in
            XCTFail("Should be skipped")
        }

        self.notificationRegistrar.onCheckStatus = {
            return(.authorized, [])
        }

        let success = await self.push.enableUserPushNotifications()
        XCTAssertTrue(success)
    }

    func testEnableUserNotificationsAuthorized() async throws {
        // Make sure updates are called through permissions manager
        let permissionsManagerCalled = self.expectation(
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
        XCTAssertTrue(success)

        await self.fulfillment(of: [permissionsManagerCalled], timeout: 10.0)
    }

    func testEnableUserNotificationsDenied() async throws {
        self.notificationRegistrar.onCheckStatus = {
            return(.denied, [])
        }

        let enabled = self.expectation(description: "Enabled")
        let success = await self.push.enableUserPushNotifications()
        enabled.fulfill()
        XCTAssertFalse(success)

        await self.fulfillment(of: [enabled], timeout: 10.0)
    }

    func testSkipWhenEphemeralDisabled() async throws {
        let updated = self.expectation(description: "Registration updated")

        self.push.notificationOptions = [.alert, .badge]
        self.push.requestExplicitPermissionWhenEphemeral = true
        await self.serialQueue.waitForCurrentOperations()

        self.notificationRegistrar.onUpdateRegistration = {
            options,
            skipIfEphemeral in
            XCTAssertEqual([.alert, .badge], options)
            XCTAssertFalse(skipIfEphemeral)
            updated.fulfill()
        }

        self.push.userPushNotificationsEnabled = true

        await self.fulfillment(of: [updated], timeout: 10.0)
    }

    @MainActor
    func testDeviceToken() throws {
        push.didRegisterForRemoteNotifications(
            AirshipPushTest.validDeviceToken.hexData
        )
        XCTAssertEqual(AirshipPushTest.validDeviceToken, self.push.deviceToken)
    }

    func testSetQuietTime() throws {
        self.push.setQuietTimeStartHour(
            12,
            startMinute: 30,
            endHour: 14,
            endMinute: 58
        )
        XCTAssertEqual(
            "12:30",
            self.push.quietTime?.startString
        )
        XCTAssertEqual(
            "14:58",
            self.push.quietTime?.endString
        )
        XCTAssertTrue(self.channel.updateRegistrationCalled)
        let expected = try QuietTimeSettings(startHour: 12, startMinute: 30, endHour: 14, endMinute: 58)
        XCTAssertEqual(expected, self.push.quietTime)
    }


    func testSetQuietTimeInvalid() throws {
        XCTAssertNil(self.push.quietTime)

        self.push.setQuietTimeStartHour(
            25,
            startMinute: 30,
            endHour: 14,
            endMinute: 58
        )
        XCTAssertNil(self.push.quietTime)

        self.push.setQuietTimeStartHour(
            12,
            startMinute: 61,
            endHour: 14,
            endMinute: 58
        )
        XCTAssertNil(self.push.quietTime)
    }

    func testSetTimeZone() throws {
        self.push.timeZone = NSTimeZone(abbreviation: "HST")
        XCTAssertEqual("HST", self.push.timeZone?.abbreviation)
        self.push.timeZone = nil
        XCTAssertEqual(NSTimeZone.default as NSTimeZone, self.push.timeZone)
    }

    @MainActor
    func testChannelPayloadRegistered() async throws {
        self.push.didRegisterForRemoteNotifications(
            AirshipPushTest.validDeviceToken.hexData
        )

        let payload = await self.channel.channelPayload

        XCTAssertEqual(AirshipPushTest.validDeviceToken, payload.channel.pushAddress)
        XCTAssertTrue(
            payload.channel.iOSChannelSettings?.isTimeSensitive == false
        )
        XCTAssertTrue(
            payload.channel.iOSChannelSettings?.isScheduledSummary == false
        )
    }

    func testChannelPayloadNotRegistered() async throws {
        let payload = await self.channel.channelPayload

        XCTAssertNil(payload.channel.pushAddress)
        XCTAssertFalse(payload.channel.isOptedIn)
        XCTAssertFalse(payload.channel.isBackgroundEnabled)
        XCTAssertNil(payload.channel.iOSChannelSettings?.quietTime)
        XCTAssertNil(payload.channel.iOSChannelSettings?.quietTimeTimeZone)
        XCTAssertTrue(
            payload.channel.iOSChannelSettings?.isTimeSensitive == false
        )
        XCTAssertTrue(
            payload.channel.iOSChannelSettings?.isScheduledSummary == false
        )
        XCTAssertNil(payload.channel.iOSChannelSettings?.badge)
    }

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

        let enabled = self.expectation(description: "Registration updated")
        let status = await self.permissionsManager.requestPermission(
            .displayNotifications,
            enableAirshipUsageOnGrant: true
        )
        enabled.fulfill()
        XCTAssertEqual(.granted, status)

        await self.fulfillment(of: [enabled], timeout: 10.0)

        let payload = await self.channel.channelPayload

        XCTAssertEqual(AirshipPushTest.validDeviceToken, payload.channel.pushAddress)
        XCTAssertTrue(payload.channel.isOptedIn)
        XCTAssertTrue(payload.channel.isBackgroundEnabled)
        XCTAssertTrue(
            payload.channel.iOSChannelSettings?.isTimeSensitive == true
        )
        XCTAssertTrue(
            payload.channel.iOSChannelSettings?.isScheduledSummary == true
        )
    }

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

        XCTAssertEqual(
            "01:30",
            payload.channel.iOSChannelSettings?.quietTime?.start
        )
        XCTAssertEqual(
            "02:30",
            payload.channel.iOSChannelSettings?.quietTime?.end
        )
        XCTAssertEqual(
            "America/New_York",
            payload.channel.iOSChannelSettings?.quietTimeTimeZone
        )
    }

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

        XCTAssertNil(payload.channel.iOSChannelSettings?.quietTime)
        XCTAssertNil(payload.channel.iOSChannelSettings?.quietTimeTimeZone)
    }

    @MainActor
    func testChannelPayloadAutoBadge() async throws {
        self.push.autobadgeEnabled = true
        try await self.push.setBadgeNumber(10)

        let payload = await self.channel.channelPayload

        XCTAssertEqual(10, payload.channel.iOSChannelSettings?.badge)
    }

    func testAnalyticsHeadersOptedOut() async throws {
        let expected = [
            "X-UA-Channel-Opted-In": "false",
            "X-UA-Notification-Prompted": "false",
            "X-UA-Channel-Background-Enabled": "false",
        ]
        let headers = await self.analtyics.headers
        XCTAssertEqual(expected, headers)
    }

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

        let enabled = self.expectation(description: "Registration updated")
        let status = await self.permissionsManager.requestPermission(
            .displayNotifications,
            enableAirshipUsageOnGrant: true
        )
        enabled.fulfill()
        XCTAssertEqual(.granted, status)
        await self.fulfillment(of: [enabled], timeout: 10.0)

        let expected = [
            "X-UA-Channel-Opted-In": "true",
            "X-UA-Notification-Prompted": "true",
            "X-UA-Channel-Background-Enabled": "true",
            "X-UA-Push-Address": AirshipPushTest.validDeviceToken,
        ]

        let headers = await self.analtyics.headers
        XCTAssertEqual(expected, headers)
    }

    func testAnalyticsHeadersPushDisabled() async throws {
        await self.push.didRegisterForRemoteNotifications(
            AirshipPushTest.validDeviceToken.hexData
        )
        self.privacyManager.disableFeatures(.push)
        let expected = [
            "X-UA-Channel-Opted-In": "false",
            "X-UA-Channel-Background-Enabled": "false",
        ]

        let headers = await self.analtyics.headers
        XCTAssertEqual(expected, headers)
    }

    @MainActor
    func testDefaultNotificationCategories() throws {
        let defaultCategories = NotificationCategories.defaultCategories()
        XCTAssertEqual(defaultCategories, notificationRegistrar.categories)
        XCTAssertEqual(defaultCategories, self.push.combinedCategories)
    }

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
        XCTAssertEqual(combined, notificationRegistrar.categories)
    }

    @MainActor
    func testRequireAuthorizationForDefaultCategories() throws {
        self.push.requireAuthorizationForDefaultCategories = true
        let defaultCategories = NotificationCategories.defaultCategories(
            withRequireAuth: true
        )
        XCTAssertEqual(defaultCategories, notificationRegistrar.categories)
        XCTAssertEqual(defaultCategories, self.push.combinedCategories)
    }

    @MainActor
    func testBadge() async throws {
        try await self.push.setBadgeNumber(100)
        XCTAssertEqual(100, self.badger.applicationIconBadgeNumber)
    }

    @MainActor
    func testAutoBadge() async throws {
        self.push.autobadgeEnabled = false
        try await self.push.setBadgeNumber(10)
        XCTAssertFalse(self.channel.updateRegistrationCalled)

        self.push.autobadgeEnabled = true
        XCTAssertTrue(self.channel.updateRegistrationCalled)

        self.channel.updateRegistrationCalled = false
        try await self.push.setBadgeNumber(1)
        XCTAssertTrue(self.channel.updateRegistrationCalled)

        self.channel.updateRegistrationCalled = false
        self.push.autobadgeEnabled = false
        XCTAssertTrue(self.channel.updateRegistrationCalled)
    }

    @MainActor
    func testResetBadge() async throws {
        try await self.push.setBadgeNumber(1000)
        XCTAssertEqual(1000, self.push.badgeNumber)

        try await self.push.resetBadge()
        XCTAssertEqual(0, self.push.badgeNumber)
        XCTAssertEqual(0, self.badger.applicationIconBadgeNumber)
    }

    func testActiveChecksRegistration() async  {
        self.notificationRegistrar.onCheckStatus = {
            return (.authorized, [.alert])
        }

        self.notificationCenter.post(
            name: AppStateTracker.didBecomeActiveNotification,
            object: nil
        )

        await self.serialQueue.waitForCurrentOperations()

        XCTAssertEqual(.authorized, self.push.authorizationStatus)
        let settings = self.push.authorizedNotificationSettings
        XCTAssertEqual([.alert], settings)
        XCTAssertTrue(self.push.userPromptedForNotifications)
    }

    func testAuthorizedStatusUpdatesChannelRegistration() async {
        self.notificationRegistrar.onCheckStatus = {
            return(.authorized, [.alert])
        }

        self.notificationCenter.post(
            name: AppStateTracker.didBecomeActiveNotification,
            object: nil
        )

        await self.serialQueue.waitForCurrentOperations()
        XCTAssertTrue(self.channel.updateRegistrationCalled)
    }

    func testDefaultOptions() {
        XCTAssertEqual([.alert, .badge, .sound], self.push.notificationOptions)
    }

    func testDefaultOptionsProvisional() async {
        self.notificationRegistrar.onCheckStatus = {
            return(.provisional, [])
        }

        let completed = self.expectation(description: "Completed")
        let _ = await self.permissionsManager.requestPermission(.displayNotifications)
        completed.fulfill()


        self.push.userPushNotificationsEnabled = true
        await self.fulfillment(of: [completed], timeout: 10.0)

        XCTAssertEqual(
            [.alert, .badge, .sound, .provisional],
            self.push.notificationOptions
        )
    }

    @MainActor
    func testCategoriesWhenAppIsHandlingAuthorization() {
        self.notificationRegistrar.categories = nil
        self.config.requestAuthorizationToUseNotifications = false
        self.push = createPush()

        let customCategory = UNNotificationCategory(
            identifier: "something",
            actions: [],
            intentIdentifiers: ["intents"]
        )
        self.push.customCategories = Set([customCategory])

        XCTAssertNil(self.notificationRegistrar.categories)
    }

    @MainActor
    func testPermissionsDelgateWhenAppIsHandlingAuthorization() {
        XCTAssertTrue(
            self.permissionsManager.configuredPermissions.contains(
                .displayNotifications
            )
        )
        self.permissionsManager.setDelegate(
            nil,
            permission: .displayNotifications
        )

        XCTAssertFalse(
            self.permissionsManager.configuredPermissions.contains(
                .displayNotifications
            )
        )
        self.config.requestAuthorizationToUseNotifications = false
        self.push = createPush()

        XCTAssertTrue(
            self.permissionsManager.configuredPermissions.contains(
                .displayNotifications
            )
        )
    }

    @MainActor
    func testForwardNotificationRegistrationFinished() {
        self.push.registrationDelegate = self.registrationDelegate

        self.notificationRegistrar.onCheckStatus = {
            return(.provisional, [.badge])
        }

        let called = self.expectation(description: "Delegate called")
        self.registrationDelegate.onNotificationRegistrationFinished = {
            settings,
            categories,
            status in
            XCTAssertEqual([.badge], settings)
            XCTAssertEqual(self.push.combinedCategories, categories)
            XCTAssertEqual(.provisional, status)
            called.fulfill()
        }

        self.push.userPushNotificationsEnabled = true
        self.wait(for: [called], timeout: 10.0)
    }

    @MainActor
    func testForwardAuthorizedSettingsChanges() {
        self.push.registrationDelegate = self.registrationDelegate
        self.notificationRegistrar.onCheckStatus = {
            return(.provisional, [.alert])
        }

        let called = self.expectation(description: "Delegate called")
        self.registrationDelegate.onNotificationAuthorizedSettingsDidChange = {
            settings in
            XCTAssertEqual([.alert], settings)
            called.fulfill()
        }

        self.push.userPushNotificationsEnabled = true
        self.wait(for: [called], timeout: 10.0)
    }

    @MainActor
    func testForwardAuthorizedSettingsChangesForeground() {
        self.push.registrationDelegate = self.registrationDelegate
        self.notificationRegistrar.onCheckStatus = {
            return(.provisional, [.badge])
        }

        let called = self.expectation(description: "Delegate called")
        self.registrationDelegate.onNotificationAuthorizedSettingsDidChange = {
            settings in
            XCTAssertEqual([.badge], settings)
            called.fulfill()
        }

        self.notificationCenter.post(
            name: AppStateTracker.didBecomeActiveNotification,
            object: nil
        )

        self.wait(for: [called], timeout: 10.0)
    }

    @MainActor
    func testForwardAPNSRegistrationSucceeded() {
        let expectedToken = AirshipPushTest.validDeviceToken.hexData

        self.push.registrationDelegate = self.registrationDelegate

        let called = self.expectation(description: "Delegate called")
        self.registrationDelegate.onAPNSRegistrationSucceeded = { token in
            XCTAssertEqual(expectedToken, token)
            called.fulfill()
        }

        self.push.didRegisterForRemoteNotifications(expectedToken)
        self.wait(for: [called], timeout: 10.0)
    }

    @MainActor
    func testForwardAPNSRegistrationFailed() {
        let expectedError = AirshipErrors.error("something")

        self.push.registrationDelegate = self.registrationDelegate

        let called = self.expectation(description: "Delegate called")
        self.registrationDelegate.onAPNSRegistrationFailed = { error in
            XCTAssertEqual(
                expectedError.localizedDescription,
                error.localizedDescription
            )
            called.fulfill()
        }

        self.push.didFailToRegisterForRemoteNotifications(expectedError)
        self.wait(for: [called], timeout: 10.0)
    }

    @MainActor
    func testReceivedForegroundNotification() async {
        let expected = ["cool": "payload"]

        let result = await self.push.didReceiveRemoteNotification(
            expected,
            isForeground: true
        )

        let res: UIBackgroundFetchResult = result as! UIBackgroundFetchResult
        XCTAssertEqual(UIBackgroundFetchResult.noData, res)
    }

    @MainActor
    func testForwardReceivedForegroundNotification() async {
        let expected = ["cool": "payload"]
        self.push.pushNotificationDelegate = self.pushDelegate

        self.pushDelegate.onReceivedForegroundNotification = {
            notificaiton in
            XCTAssertEqual(
                expected as NSDictionary,
                notificaiton as NSDictionary
            )
        }

        let result = await self.push.didReceiveRemoteNotification(expected, isForeground: true)

        let res: UIBackgroundFetchResult = result as! UIBackgroundFetchResult
        XCTAssertEqual(UIBackgroundFetchResult.noData, res)
    }

    @MainActor
    func testReceivedBackgroundNotification() async {
        let expected = ["cool": "payload"]

        let result = await self.push.didReceiveRemoteNotification(
            expected,
            isForeground: false
        )

        let res: UIBackgroundFetchResult = result as! UIBackgroundFetchResult
        XCTAssertEqual(UIBackgroundFetchResult.noData, res)
    }

    @MainActor
    func testForwardReceivedBackgroundNotification() async {
        let expected = ["cool": "payload"]
        self.push.pushNotificationDelegate = self.pushDelegate

        self.pushDelegate.onReceivedBackgroundNotification = {
            notificaiton in
            XCTAssertEqual(
                expected as NSDictionary,
                notificaiton as NSDictionary
            )
            return .newData
        }

        let result = await self.push.didReceiveRemoteNotification(
            expected,
            isForeground: false
        )

        let res: UIBackgroundFetchResult = result as! UIBackgroundFetchResult
        XCTAssertEqual(UIBackgroundFetchResult.newData, res)
    }

    @MainActor
    func testOptionsPermissionDelegate() async {
        self.push.userPushNotificationsEnabled = false
        self.push.notificationOptions = .alert

        let updated = self.expectation(description: "Registration updated")
        self.notificationRegistrar.onUpdateRegistration = {
            options,
            skipIfEphemeral in
            XCTAssertTrue(skipIfEphemeral)
            if options == [.alert] {
                updated.fulfill()
            }
        }

        let completionHandlerCalled = self.expectation(
            description: "Completion handler called"
        )
        let _ = await self.permissionsManager.requestPermission(.displayNotifications)
        completionHandlerCalled.fulfill()

        await self.fulfillment(of: [updated, completionHandlerCalled], timeout: 10)
    }

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
        XCTAssertEqual(
            AirshipNotificationStatus(
                isUserNotificationsEnabled: true,
                areNotificationsAllowed: true,
                isPushPrivacyFeatureEnabled: true,
                isPushTokenRegistered: true,
                displayNotificationStatus: .granted
            ),
            status
        )
    }

    @MainActor
    func testNotificationStatusNoTokenRegistration() async {
        self.push.didRegisterForRemoteNotifications(
            AirshipPushTest.validDeviceToken.hexData
        )

        var status = await self.push.notificationStatus
        XCTAssertEqual(
            AirshipNotificationStatus(
                isUserNotificationsEnabled: false,
                areNotificationsAllowed: false,
                isPushPrivacyFeatureEnabled: true,
                isPushTokenRegistered: false,
                displayNotificationStatus: .notDetermined
            ),
            status
        )

        self.apnsRegistrar.isRegisteredForRemoteNotifications = true

        status = await self.push.notificationStatus
        XCTAssertEqual(
            AirshipNotificationStatus(
                isUserNotificationsEnabled: false,
                areNotificationsAllowed: false,
                isPushPrivacyFeatureEnabled: true,
                isPushTokenRegistered: true,
                displayNotificationStatus: .notDetermined
            ),
            status
        )
    }


    @MainActor
    func testNotificationStatusAllowed() async {
        self.notificationRegistrar.onCheckStatus = {
            return (.notDetermined, [.alert])
        }

        var status = await self.push.notificationStatus
        XCTAssertEqual(
            AirshipNotificationStatus(
                isUserNotificationsEnabled: false,
                areNotificationsAllowed: false,
                isPushPrivacyFeatureEnabled: true,
                isPushTokenRegistered: false,
                displayNotificationStatus: .notDetermined
            ),
            status
        )

        self.notificationRegistrar.onCheckStatus = {
            return (.authorized, [.alert])
        }

        status = await self.push.notificationStatus
        XCTAssertEqual(
            AirshipNotificationStatus(
                isUserNotificationsEnabled: false,
                areNotificationsAllowed: true,
                isPushPrivacyFeatureEnabled: true,
                isPushTokenRegistered: false,
                displayNotificationStatus: .granted
            ),
            status
        )
    }

    @MainActor
    func testChannelRegistrationWaitsForToken() async {
        apnsRegistrar.isRegisteredForRemoteNotifications = true

        let startedCRATask = self.expectation(description: "Started CRA")

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
            return await self.channel.channelPayload
        }.value


        XCTAssertNotNil(payload.channel.pushAddress)
    }

    @MainActor
    func testAPNSRegistrationFinishedDelegateFallbackSuccess() async {
        let expectedToken = "some-token"
        let delegate = TestRegistraitonDelegate()
        let expectation = self.expectation(description: "Delegate called")
        delegate.onAPNSRegistrationSucceeded = { tokenData in
            XCTAssertEqual(expectedToken.hexData, tokenData)
            expectation.fulfill()
        }

        self.push.registrationDelegate = delegate
        self.push.onAPNSRegistrationFinished = nil

        self.push.didRegisterForRemoteNotifications(expectedToken.hexData)
        await self.fulfillment(of: [expectation], timeout: 10.0)
    }

    @MainActor
    func testAPNSRegistrationFinishedDelegateFallbackFailure() async {
        let expectedError = AirshipErrors.error("some error")
        let delegate = TestRegistraitonDelegate()
        let expectation = self.expectation(description: "Delegate called")
        delegate.onAPNSRegistrationFailed = { error in
            XCTAssertEqual(expectedError.localizedDescription, error.localizedDescription)
            expectation.fulfill()
        }

        self.push.registrationDelegate = delegate
        self.push.onAPNSRegistrationFinished = nil

        self.push.didFailToRegisterForRemoteNotifications(expectedError)
        await self.fulfillment(of: [expectation], timeout: 10.0)
    }

    @MainActor
    func testNotificationRegistrationFinishedCallback() async {
        let expectation = self.expectation(description: "Callback called")
        self.notificationRegistrar.onCheckStatus = {
            return (.authorized, [.alert])
        }

        self.push.onNotificationRegistrationFinished = { result in
            XCTAssertEqual(.authorized, result.status)
            XCTAssertEqual([.alert], result.authorizedSettings)
            XCTAssertEqual(self.push.combinedCategories, result.categories)
            expectation.fulfill()
        }

        let _ = await self.permissionsManager.requestPermission(.displayNotifications)
        await self.fulfillment(of: [expectation], timeout: 10.0)
    }

    @MainActor
    func testNotificationRegistrationFinishedDelegateFallback() async {
        let delegate = TestRegistraitonDelegate()
        let expectation = self.expectation(description: "Delegate called")
        self.notificationRegistrar.onCheckStatus = {
            return (.authorized, [.alert])
        }

        delegate.onNotificationRegistrationFinished = { settings, categories, status in
            XCTAssertEqual(.authorized, status)
            XCTAssertEqual([.alert], settings)
            XCTAssertEqual(self.push.combinedCategories, categories)
            expectation.fulfill()
        }
        self.push.registrationDelegate = delegate
        self.push.onNotificationRegistrationFinished = nil

        let _ = await self.permissionsManager.requestPermission(.displayNotifications)
        await self.fulfillment(of: [expectation], timeout: 10.0)
    }

    @MainActor
    func testAuthorizedSettingsDidChangeCallback() async {
        let expectation = self.expectation(description: "Callback called")
        self.notificationRegistrar.onCheckStatus = {
            return (.authorized, [.sound])
        }

        self.push.onNotificationAuthorizedSettingsDidChange = { settings in
            XCTAssertEqual([.sound], settings)
            expectation.fulfill()
        }

        let _ = await self.permissionsManager.requestPermission(.displayNotifications)
        await self.fulfillment(of: [expectation], timeout: 10.0)
    }

    @MainActor
    func testAuthorizedSettingsDidChangeDelegateFallback() async {
        let delegate = TestRegistraitonDelegate()
        let expectation = self.expectation(description: "Delegate called")
        self.notificationRegistrar.onCheckStatus = {
            return (.authorized, [.sound])
        }

        delegate.onNotificationAuthorizedSettingsDidChange = { settings in
            XCTAssertEqual([.sound], settings)
            expectation.fulfill()
        }
        self.push.registrationDelegate = delegate
        self.push.onNotificationAuthorizedSettingsDidChange = nil

        let _ = await self.permissionsManager.requestPermission(.displayNotifications)
        await self.fulfillment(of: [expectation], timeout: 10.0)
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
