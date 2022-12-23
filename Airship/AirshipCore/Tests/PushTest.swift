// Copyright Airship and Contributors

import XCTest

@testable import AirshipCore

class PushTest: XCTestCase {

    private static let validDeviceToken = "0123456789abcdef0123456789abcdef"

    private let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let channel = TestChannel()
    private let analtyics = TestAnalytics()
    private let permissionsManager = PermissionsManager()
    private let notificationCenter = NotificationCenter()
    private let notificationRegistrar = TestNotificationRegistrar()
    private let apnsRegistrar = TestAPNSRegistrar()
    private let badger = TestBadger()
    private let dispatcher = TestDispatcher()
    private let registrationDelegate = TestRegistraitonDelegate()
    private let pushDelegate = TestPushNotificationDelegate()

    private var config = Config()
    private var privacyManager: PrivacyManager!
    private var push: Push!

    override func setUpWithError() throws {
        self.privacyManager = PrivacyManager(
            dataStore: dataStore,
            defaultEnabledFeatures: .all,
            notificationCenter: notificationCenter
        )
        self.push = createPush()
        self.channel.updateRegistrationCalled = false
    }

    func createPush() -> Push {
        return Push(
            config: RuntimeConfig(
                config: self.config,
                dataStore: self.dataStore
            ),
            dataStore: dataStore,
            channel: channel,
            analytics: analtyics,
            privacyManager: privacyManager,
            permissionsManager: permissionsManager,
            notificationCenter: notificationCenter,
            notificationRegistrar: notificationRegistrar,
            apnsRegistrar: apnsRegistrar,
            badger: badger,
            mainDispatcher: dispatcher
        )
    }

    func testBackgroundPushNotificationsEnabled() throws {
        XCTAssertTrue(self.push.backgroundPushNotificationsEnabled)
        XCTAssertFalse(self.channel.updateRegistrationCalled)

        self.push.backgroundPushNotificationsEnabled = false
        XCTAssertTrue(self.channel.updateRegistrationCalled)
    }

    func testNotificationsPromptedAuthorizedStatus() throws {
        XCTAssertFalse(self.push.userPromptedForNotifications)

        self.notificationRegistrar.onCheckStatus = { completionHandler in
            completionHandler(.authorized, [])
        }

        let completed = self.expectation(description: "Completed")
        self.permissionsManager.requestPermission(.displayNotifications) { _ in
            completed.fulfill()
        }

        self.wait(for: [completed], timeout: 1)
        XCTAssertTrue(self.push.userPromptedForNotifications)
    }

    func testNotificationsPromptedDeniedStatus() throws {
        XCTAssertFalse(self.push.userPromptedForNotifications)

        self.notificationRegistrar.onCheckStatus = { completionHandler in
            completionHandler(.denied, [])
        }

        let completed = self.expectation(description: "Completed")
        self.permissionsManager.requestPermission(.displayNotifications) { _ in
            completed.fulfill()
        }

        self.wait(for: [completed], timeout: 1)
        XCTAssertTrue(self.push.userPromptedForNotifications)
    }

    func testNotificationsPromptedEphemeralStatus() throws {
        XCTAssertFalse(self.push.userPromptedForNotifications)

        self.notificationRegistrar.onCheckStatus = { completionHandler in
            completionHandler(.ephemeral, [])
        }

        let completed = self.expectation(description: "Completed")
        self.permissionsManager.requestPermission(.displayNotifications) { _ in
            completed.fulfill()
        }

        self.wait(for: [completed], timeout: 1)
        XCTAssertFalse(self.push.userPromptedForNotifications)
    }

    func testNotificationsPromptedNotDeterminedStatus() throws {
        XCTAssertFalse(self.push.userPromptedForNotifications)

        self.notificationRegistrar.onCheckStatus = { completionHandler in
            completionHandler(.notDetermined, [])
        }

        let completed = self.expectation(description: "Completed")
        self.permissionsManager.requestPermission(.displayNotifications) { _ in
            completed.fulfill()
        }

        self.wait(for: [completed], timeout: 1)
        XCTAssertFalse(self.push.userPromptedForNotifications)
    }

    /// Test that once prompted always prompted
    func testNotificationsPromptedStaysPrompted() throws {
        XCTAssertFalse(self.push.userPromptedForNotifications)

        self.notificationRegistrar.onCheckStatus = { completionHandler in
            completionHandler(.authorized, [])
        }

        let completed = self.expectation(description: "Completed")
        self.permissionsManager.requestPermission(.displayNotifications) { _ in
            completed.fulfill()
        }

        self.wait(for: [completed], timeout: 1)

        self.notificationRegistrar.onCheckStatus = { completionHandler in
            completionHandler(.notDetermined, [])
        }

        let completedAgain = self.expectation(description: "Completed Again")
        self.permissionsManager.requestPermission(.displayNotifications) { _ in
            completedAgain.fulfill()
        }

        self.wait(for: [completedAgain], timeout: 1)

        XCTAssertTrue(self.push.userPromptedForNotifications)
    }

    func testUserPushNotificationsEnabled() throws {
        // Make sure updates are called through permissions manager
        let permissionsManagerCalled = self.expectation(
            description: "Permissions manager called"
        )
        self.permissionsManager.addRequestExtender(
            permission: .displayNotifications
        ) { _, completionHandler in
            permissionsManagerCalled.fulfill()
            completionHandler()
        }

        self.push.notificationOptions = [.alert, .badge]
        self.push.requestExplicitPermissionWhenEphemeral = false

        let updated = self.expectation(description: "Registration updated")
        self.notificationRegistrar.onUpdateRegistration = {
            options,
            skipIfEphemeral,
            completionHandler in
            XCTAssertEqual([.alert, .badge], options)
            XCTAssertTrue(skipIfEphemeral)
            updated.fulfill()
            completionHandler()
        }

        self.push.userPushNotificationsEnabled = true
        self.wait(for: [permissionsManagerCalled, updated], timeout: 1)
    }

    func testUserPushNotificationsDisabled() throws {
        let enabled = self.expectation(description: "Registration updated")
        self.notificationRegistrar.onUpdateRegistration = {
            options,
            skipIfEphemeral,
            completionHandler in
            XCTAssertEqual([.badge, .alert, .sound], options)
            XCTAssertTrue(skipIfEphemeral)
            enabled.fulfill()
            completionHandler()
        }

        self.push.userPushNotificationsEnabled = true
        self.wait(for: [enabled], timeout: 1)

        let disabled = self.expectation(description: "Registration updated")
        self.notificationRegistrar.onUpdateRegistration = {
            options,
            skipIfEphemeral,
            completionHandler in
            XCTAssertEqual([], options)
            XCTAssertTrue(skipIfEphemeral)
            disabled.fulfill()
            completionHandler()
        }

        self.push.userPushNotificationsEnabled = false
        self.wait(for: [disabled], timeout: 1)
    }

    /// Test that we always ephemeral when disabling notifications
    func testUserPushNotificationsSkipEphemeral() throws {
        self.push.requestExplicitPermissionWhenEphemeral = false

        let enabled = self.expectation(description: "Registration updated")
        self.notificationRegistrar.onUpdateRegistration = {
            options,
            skipIfEphemeral,
            completionHandler in
            XCTAssertEqual([.badge, .alert, .sound], options)
            XCTAssertTrue(skipIfEphemeral)
            enabled.fulfill()
            completionHandler()
        }

        self.push.userPushNotificationsEnabled = true
        self.wait(for: [enabled], timeout: 1)

        let disabled = self.expectation(description: "Registration updated")
        self.notificationRegistrar.onUpdateRegistration = {
            options,
            skipIfEphemeral,
            completionHandler in
            XCTAssertEqual([], options)
            XCTAssertTrue(skipIfEphemeral)
            disabled.fulfill()
            completionHandler()
        }

        self.push.userPushNotificationsEnabled = false
        self.wait(for: [disabled], timeout: 1)
    }

    func testEnableUserNotificationsAuthorized() throws {
        // Make sure updates are called through permissions manager
        let permissionsManagerCalled = self.expectation(
            description: "Permissions manager called"
        )
        self.permissionsManager.addRequestExtender(
            permission: .displayNotifications
        ) { _, completionHandler in
            permissionsManagerCalled.fulfill()
            completionHandler()
        }

        self.push.notificationOptions = [.alert, .badge]
        self.push.requestExplicitPermissionWhenEphemeral = false

        let updated = self.expectation(description: "Registration updated")
        self.notificationRegistrar.onUpdateRegistration = {
            options,
            skipIfEphemeral,
            completionHandler in
            XCTAssertEqual([.alert, .badge], options)
            XCTAssertTrue(skipIfEphemeral)
            updated.fulfill()
            completionHandler()
        }

        self.notificationRegistrar.onCheckStatus = { completionHandler in
            completionHandler(.authorized, [])
        }

        let enabled = self.expectation(description: "Enabled")
        self.push.enableUserPushNotifications { success in
            enabled.fulfill()
            XCTAssertTrue(success)
        }

        self.wait(
            for: [permissionsManagerCalled, updated, enabled],
            timeout: 1
        )
    }

    func testEnableUserNotificationsDenied() throws {
        self.notificationRegistrar.onCheckStatus = { completionHandler in
            completionHandler(.denied, [])
        }

        let enabled = self.expectation(description: "Enabled")
        self.push.enableUserPushNotifications { success in
            enabled.fulfill()
            XCTAssertFalse(success)
        }

        self.wait(for: [enabled], timeout: 1)
    }

    func testSkipWhenEphemeralDisabled() throws {
        self.push.notificationOptions = [.alert, .badge]
        self.push.requestExplicitPermissionWhenEphemeral = true

        let updated = self.expectation(description: "Registration updated")
        self.notificationRegistrar.onUpdateRegistration = {
            options,
            skipIfEphemeral,
            completionHandler in
            XCTAssertEqual([.alert, .badge], options)
            XCTAssertFalse(skipIfEphemeral)
            updated.fulfill()
            completionHandler()
        }

        self.push.userPushNotificationsEnabled = true
        self.wait(for: [updated], timeout: 1)
    }

    func testDeviceToken() throws {
        push.didRegisterForRemoteNotifications(
            PushTest.validDeviceToken.hexData
        )
        XCTAssertEqual(PushTest.validDeviceToken, self.push.deviceToken)
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
            self.push.quietTime![Push.quietTimeStartKey] as! String
        )
        XCTAssertEqual(
            "14:58",
            self.push.quietTime![Push.quietTimeEndKey] as! String
        )
        XCTAssertTrue(self.channel.updateRegistrationCalled)
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

    func testChannelPayloadRegistered() async throws {
        self.push.didRegisterForRemoteNotifications(
            PushTest.validDeviceToken.hexData
        )

        let payload = await self.channel.channelPayload

        XCTAssertEqual(PushTest.validDeviceToken, payload.channel.pushAddress)
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

    func testChannelPayloadNotificationsEnabled() async throws {
        self.push.didRegisterForRemoteNotifications(
            PushTest.validDeviceToken.hexData
        )
        apnsRegistrar.isRegisteredForRemoteNotifications = true
        apnsRegistrar.isRemoteNotificationBackgroundModeEnabled = true
        apnsRegistrar.isBackgroundRefreshStatusAvailable = true

        self.notificationRegistrar.onCheckStatus = { completionHandler in
            completionHandler(
                .authorized,
                [.timeSensitive, .scheduledDelivery, .alert]
            )
        }

        let enabled = self.expectation(description: "Registration updated")
        self.permissionsManager.requestPermission(
            .displayNotifications,
            enableAirshipUsageOnGrant: true
        ) { status in
            enabled.fulfill()
            XCTAssertEqual(.granted, status)
        }
        self.wait(for: [enabled], timeout: 2)

        let payload = await self.channel.channelPayload

        XCTAssertEqual(PushTest.validDeviceToken, payload.channel.pushAddress)
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

    func testChannelPayloadAutoBadge() async throws {
        self.push.autobadgeEnabled = true
        self.push.badgeNumber = 10

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

    func testAnalyticsHeadersOptedIn() async throws {
        self.push.didRegisterForRemoteNotifications(
            PushTest.validDeviceToken.hexData
        )
        apnsRegistrar.isRegisteredForRemoteNotifications = true
        apnsRegistrar.isRemoteNotificationBackgroundModeEnabled = true
        apnsRegistrar.isBackgroundRefreshStatusAvailable = true

        self.notificationRegistrar.onCheckStatus = { completionHandler in
            completionHandler(
                .authorized,
                [.timeSensitive, .scheduledDelivery, .alert]
            )
        }

        let enabled = self.expectation(description: "Registration updated")
        self.permissionsManager.requestPermission(
            .displayNotifications,
            enableAirshipUsageOnGrant: true
        ) { status in
            enabled.fulfill()
            XCTAssertEqual(.granted, status)
        }
        self.wait(for: [enabled], timeout: 2)

        let expected = [
            "X-UA-Channel-Opted-In": "true",
            "X-UA-Notification-Prompted": "true",
            "X-UA-Channel-Background-Enabled": "true",
            "X-UA-Push-Address": PushTest.validDeviceToken,
        ]

        let headers = await self.analtyics.headers
        XCTAssertEqual(expected, headers)
    }

    func testAnalyticsHeadersPushDisabled() async throws {
        self.push.didRegisterForRemoteNotifications(
            PushTest.validDeviceToken.hexData
        )
        self.privacyManager.disableFeatures(.push)
        let expected = [
            "X-UA-Channel-Opted-In": "false",
            "X-UA-Channel-Background-Enabled": "false",
        ]

        let headers = await self.analtyics.headers
        XCTAssertEqual(expected, headers)
    }

    func testDefaultNotificationCategories() throws {
        let defaultCategories = NotificationCategories.defaultCategories()
        XCTAssertEqual(defaultCategories, notificationRegistrar.categories)
        XCTAssertEqual(defaultCategories, self.push.combinedCategories)
    }

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

    func testRequireAuthorizationForDefaultCategories() throws {
        self.push.requireAuthorizationForDefaultCategories = true
        let defaultCategories = NotificationCategories.defaultCategories(
            withRequireAuth: true
        )
        XCTAssertEqual(defaultCategories, notificationRegistrar.categories)
        XCTAssertEqual(defaultCategories, self.push.combinedCategories)
    }

    func testBadge() throws {
        self.push.badgeNumber = 100
        XCTAssertEqual(100, self.badger.applicationIconBadgeNumber)
    }

    func testAutoBadge() throws {
        self.push.autobadgeEnabled = false
        self.push.badgeNumber = 100
        XCTAssertFalse(self.channel.updateRegistrationCalled)

        self.push.autobadgeEnabled = true
        XCTAssertTrue(self.channel.updateRegistrationCalled)

        self.channel.updateRegistrationCalled = false
        self.push.badgeNumber = 100
        XCTAssertFalse(self.channel.updateRegistrationCalled)

        self.push.badgeNumber = 101
        XCTAssertTrue(self.channel.updateRegistrationCalled)

        self.channel.updateRegistrationCalled = false
        self.push.autobadgeEnabled = false
        XCTAssertTrue(self.channel.updateRegistrationCalled)
    }

    func testResetBadge() {
        self.push.badgeNumber = 1000
        self.push.resetBadge()
        XCTAssertEqual(0, self.push.badgeNumber)
        XCTAssertEqual(0, self.badger.applicationIconBadgeNumber)
    }

    func testActiveChecksRegistration() {
        let updated = self.expectation(description: "Updated")
        self.notificationRegistrar.onCheckStatus = { completion in
            completion(.authorized, [.alert])
            updated.fulfill()
        }

        self.notificationCenter.post(
            name: AppStateTracker.didBecomeActiveNotification,
            object: nil
        )

        self.wait(for: [updated], timeout: 1)

        XCTAssertEqual(.authorized, self.push.authorizationStatus)
        XCTAssertEqual([.alert], self.push.authorizedNotificationSettings)
        XCTAssertTrue(self.push.userPromptedForNotifications)
    }

    func testAuthorizedStatusUpdatesChannelRegistration() {
        let updated = self.expectation(description: "Updated")
        self.notificationRegistrar.onCheckStatus = { completion in
            completion(.authorized, [.alert])
            updated.fulfill()
        }

        self.notificationCenter.post(
            name: AppStateTracker.didBecomeActiveNotification,
            object: nil
        )

        self.wait(for: [updated], timeout: 1)

        XCTAssertTrue(self.channel.updateRegistrationCalled)
    }

    func testDefaultOptions() {
        XCTAssertEqual([.alert, .badge, .sound], self.push.notificationOptions)
    }

    func testDefaultOptionsProvisional() {
        self.notificationRegistrar.onCheckStatus = { completionHandler in
            completionHandler(.provisional, [])
        }

        let completed = self.expectation(description: "Completed")
        self.permissionsManager.requestPermission(.displayNotifications) { _ in
            completed.fulfill()
        }

        self.push.userPushNotificationsEnabled = true
        self.wait(for: [completed], timeout: 1)

        XCTAssertEqual(
            [.alert, .badge, .sound, .provisional],
            self.push.notificationOptions
        )
    }

    func testComponentEnabledUpdatesRegistration() {
        self.push.isComponentEnabled = false
        self.push.userPushNotificationsEnabled = true

        // Make sure updates are called through permissions manager
        let permissionsManagerCalled = self.expectation(
            description: "Permissions manager called"
        )
        self.permissionsManager.addRequestExtender(
            permission: .displayNotifications
        ) { _, completionHandler in
            permissionsManagerCalled.fulfill()
            completionHandler()
        }

        self.push.isComponentEnabled = true
        self.wait(for: [permissionsManagerCalled], timeout: 1)
    }

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

        XCTAssertFalse(
            self.permissionsManager.configuredPermissions.contains(
                .displayNotifications
            )
        )
    }

    func testForwardNotificationRegistrationFinished() {
        self.push.registrationDelegate = self.registrationDelegate

        self.notificationRegistrar.onCheckStatus = { completionHandler in
            completionHandler(.provisional, [.badge])
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
        self.wait(for: [called], timeout: 1)
    }

    func testForwardAuthorizedSettingsChanges() {
        self.push.registrationDelegate = self.registrationDelegate
        self.notificationRegistrar.onCheckStatus = { completionHandler in
            completionHandler(.provisional, [.alert])
        }

        let called = self.expectation(description: "Delegate called")
        self.registrationDelegate.onNotificationAuthorizedSettingsDidChange = {
            settings in
            XCTAssertEqual([.alert], settings)
            called.fulfill()
        }

        self.push.userPushNotificationsEnabled = true
        self.wait(for: [called], timeout: 1)
    }

    func testForwardAuthorizedSettingsChangesForeground() {
        self.push.registrationDelegate = self.registrationDelegate
        self.notificationRegistrar.onCheckStatus = { completionHandler in
            completionHandler(.provisional, [.badge])
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

        self.wait(for: [called], timeout: 1)
    }

    func testForwardAPNSRegistrationSucceeded() {
        let expectedToken = PushTest.validDeviceToken.hexData

        self.push.registrationDelegate = self.registrationDelegate

        let called = self.expectation(description: "Delegate called")
        self.registrationDelegate.onAPNSRegistrationSucceeded = { token in
            XCTAssertEqual(expectedToken, token)
            called.fulfill()
        }

        self.push.didRegisterForRemoteNotifications(expectedToken)
        self.wait(for: [called], timeout: 1)
    }

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
        self.wait(for: [called], timeout: 1)
    }

    func testReceivedForegroundNotification() {
        let expected = ["cool": "payload"]

        let completionHandlerCalled = self.expectation(
            description: "Completion handler called"
        )
        self.push.didReceiveRemoteNotification(
            expected,
            isForeground: true,
            completionHandler: { result in
                let res: UIBackgroundFetchResult =
                    result as! UIBackgroundFetchResult
                XCTAssertEqual(UIBackgroundFetchResult.noData, res)
                completionHandlerCalled.fulfill()
            }
        )

        self.wait(
            for: [completionHandlerCalled],
            timeout: 1,
            enforceOrder: true
        )
    }

    func testForwardReceivedForegroundNotification() {
        let expected = ["cool": "payload"]
        self.push.pushNotificationDelegate = self.pushDelegate

        let delegateCalled = self.expectation(description: "Delegate called")
        self.pushDelegate.onReceivedForegroundNotification = {
            notificaiton,
            completionHandler in
            XCTAssertEqual(
                expected as NSDictionary,
                notificaiton as NSDictionary
            )
            delegateCalled.fulfill()
            completionHandler()
        }

        let completionHandlerCalled = self.expectation(
            description: "Completion handler called"
        )
        self.push.didReceiveRemoteNotification(
            expected,
            isForeground: true,
            completionHandler: { result in
                let res: UIBackgroundFetchResult =
                    result as! UIBackgroundFetchResult
                XCTAssertEqual(UIBackgroundFetchResult.noData, res)
                completionHandlerCalled.fulfill()
            }
        )

        self.wait(
            for: [delegateCalled, completionHandlerCalled],
            timeout: 1,
            enforceOrder: true
        )

    }

    func testReceivedBackgroundNotification() {
        let expected = ["cool": "payload"]

        let completionHandlerCalled = self.expectation(
            description: "Completion handler called"
        )
        self.push.didReceiveRemoteNotification(
            expected,
            isForeground: false,
            completionHandler: { result in
                let res: UIBackgroundFetchResult =
                    result as! UIBackgroundFetchResult
                XCTAssertEqual(UIBackgroundFetchResult.noData, res)
                completionHandlerCalled.fulfill()
            }
        )

        self.wait(
            for: [completionHandlerCalled],
            timeout: 1,
            enforceOrder: true
        )
    }

    func testForwardReceivedBackgroundNotification() {
        let expected = ["cool": "payload"]
        self.push.pushNotificationDelegate = self.pushDelegate

        let delegateCalled = self.expectation(description: "Delegate called")
        self.pushDelegate.onReceivedBackgroundNotification = {
            notificaiton,
            completionHandler in
            XCTAssertEqual(
                expected as NSDictionary,
                notificaiton as NSDictionary
            )
            delegateCalled.fulfill()
            completionHandler(.newData)
        }

        let completionHandlerCalled = self.expectation(
            description: "Completion handler called"
        )
        self.push.didReceiveRemoteNotification(
            expected,
            isForeground: false,
            completionHandler: { result in
                let res: UIBackgroundFetchResult =
                    result as! UIBackgroundFetchResult
                XCTAssertEqual(UIBackgroundFetchResult.newData, res)
                completionHandlerCalled.fulfill()
            }
        )

        self.wait(
            for: [delegateCalled, completionHandlerCalled],
            timeout: 1,
            enforceOrder: true
        )
    }

    func testOptionsPermissionDelegate() {
        self.push.userPushNotificationsEnabled = false
        self.push.notificationOptions = .alert

        let updated = self.expectation(description: "Registration updated")
        self.notificationRegistrar.onUpdateRegistration = {
            options,
            skipIfEphemeral,
            completionHandler in
            XCTAssertEqual([.alert], options)
            XCTAssertTrue(skipIfEphemeral)
            updated.fulfill()
            completionHandler()
        }

        let completionHandlerCalled = self.expectation(
            description: "Completion handler called"
        )
        self.permissionsManager.requestPermission(.displayNotifications) { _ in
            completionHandlerCalled.fulfill()
        }

        self.wait(for: [completionHandlerCalled, updated], timeout: 1)
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

class TestPushNotificationDelegate: NSObject, PushNotificationDelegate {
    var onReceivedForegroundNotification:
        (([AnyHashable: Any], () -> Void) -> Void)?
    var onReceivedBackgroundNotification:
        (([AnyHashable: Any], (UIBackgroundFetchResult) -> Void) -> Void)?
    var onReceivedNotificationResponse:
        ((UNNotificationResponse, () -> Void) -> Void)?
    var onExtend:
        (
            (UNNotificationPresentationOptions, UNNotification) ->
                UNNotificationPresentationOptions
        )?

    func receivedForegroundNotification(
        _ userInfo: [AnyHashable: Any],
        completionHandler: @escaping () -> Void
    ) {
        guard let block = onReceivedForegroundNotification else {
            completionHandler()
            return
        }
        block(userInfo, completionHandler)
    }

    func receivedBackgroundNotification(
        _ userInfo: [AnyHashable: Any],
        completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard let block = onReceivedBackgroundNotification else {
            completionHandler(.noData)
            return
        }
        block(userInfo, completionHandler)
    }

    func receivedNotificationResponse(
        _ notificationResponse: UNNotificationResponse,
        completionHandler: @escaping () -> Void
    ) {
        guard let block = onReceivedNotificationResponse else {
            completionHandler()
            return
        }
        block(notificationResponse, completionHandler)
    }

    func extend(
        _ options: UNNotificationPresentationOptions,
        notification: UNNotification
    ) -> UNNotificationPresentationOptions {
        return self.onExtend?(options, notification) ?? options
    }
}

class TestRegistraitonDelegate: NSObject, RegistrationDelegate {

    var onNotificationRegistrationFinished:
        (
            (
                UAAuthorizedNotificationSettings, Set<UNNotificationCategory>,
                UAAuthorizationStatus
            ) -> Void
        )?
    var onNotificationAuthorizedSettingsDidChange:
        ((UAAuthorizedNotificationSettings) -> Void)?
    var onAPNSRegistrationSucceeded: ((Data) -> Void)?
    var onAPNSRegistrationFailed: ((Error) -> Void)?

    func notificationRegistrationFinished(
        withAuthorizedSettings authorizedSettings:
            UAAuthorizedNotificationSettings,
        categories: Set<UNNotificationCategory>,
        status: UAAuthorizationStatus
    ) {
        self.onNotificationRegistrationFinished?(
            authorizedSettings,
            categories,
            status
        )
    }

    func notificationAuthorizedSettingsDidChange(
        _ authorizedSettings: UAAuthorizedNotificationSettings
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

class TestNotificationRegistrar: NotificationRegistrar {
    var categories: Set<UNNotificationCategory>?
    var onCheckStatus:
        (
            (
                (
                    (UAAuthorizationStatus, UAAuthorizedNotificationSettings) ->
                        Void
                )
            ) ->
                Void
        )?
    var onUpdateRegistration:
        ((UANotificationOptions, Bool, (() -> Void)) -> Void)?

    func setCategories(_ categories: Set<UNNotificationCategory>) {
        self.categories = categories
    }

    func checkStatus(
        completionHandler: @escaping (
            UAAuthorizationStatus, UAAuthorizedNotificationSettings
        ) -> Void
    ) {
        guard let callback = self.onCheckStatus else {
            completionHandler(.notDetermined, [])
            return
        }
        callback(completionHandler)
    }

    func updateRegistration(
        options: UANotificationOptions,
        skipIfEphemeral: Bool,
        completionHandler: @escaping () -> Void
    ) {
        guard let callback = self.onUpdateRegistration else {
            completionHandler()
            return
        }
        callback(options, skipIfEphemeral, completionHandler)
    }
}

class TestAPNSRegistrar: APNSRegistrar {
    var isRegisteredForRemoteNotifications: Bool = false
    var isBackgroundRefreshStatusAvailable: Bool = false
    var isRemoteNotificationBackgroundModeEnabled: Bool = false
    var registerForRemoteNotificationsCalled: Bool?

    func registerForRemoteNotifications() {
        registerForRemoteNotificationsCalled = true
    }
}

class TestBadger: Badger {
    var applicationIconBadgeNumber: Int = 0
}
