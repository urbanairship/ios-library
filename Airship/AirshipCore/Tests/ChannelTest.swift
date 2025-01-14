/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

class ChannelTest: XCTestCase {

    private let channelRegistrar = TestChannelRegistrar()
    private let localeManager = TestLocaleManager()
    private let audienceManager = TestChannelAudienceManager()
    private let appStateTracker = TestAppStateTracker()
    private let notificationCenter = AirshipNotificationCenter(notificationCenter: NotificationCenter())
    private let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private var config = AirshipConfig()
    private var privacyManager: AirshipPrivacyManager!
    private var permissionsManager: AirshipPermissionsManager!
    private var channel: AirshipChannel!

    override func setUp() async throws {

        self.privacyManager = await AirshipPrivacyManager(
            dataStore: self.dataStore,
            config: .testConfig(),
            defaultEnabledFeatures: [],
            notificationCenter: self.notificationCenter
        )
        
        self.permissionsManager = await AirshipPermissionsManager()

        self.channel = await createChannel()
    }

    @MainActor
    private func createChannel() -> AirshipChannel {
        return AirshipChannel(
            dataStore: self.dataStore,
            config: .testConfig(airshipConfig: self.config),
            privacyManager: self.privacyManager,
            permissionsManager: self.permissionsManager,
            localeManager: self.localeManager,
            audienceManager: self.audienceManager,
            channelRegistrar: self.channelRegistrar,
            notificationCenter: self.notificationCenter,
            appStateTracker: self.appStateTracker
        )
    }

    func testRegistrationFeatureEnabled() throws {
        XCTAssertFalse(self.channelRegistrar.registerCalled)
        self.privacyManager.enableFeatures(.tagsAndAttributes)
        XCTAssertTrue(self.channelRegistrar.registerCalled)
    }

    func testTags() throws {
        self.privacyManager.enableFeatures(.tagsAndAttributes)

        self.channelRegistrar.registerCalled = false
        self.channel.tags = ["foo", "bar"]

        XCTAssertEqual(["foo", "bar"], self.channel.tags)
        XCTAssertTrue(self.channelRegistrar.registerCalled)
    }

    func testEditTags() throws {
        self.privacyManager.enableFeatures(.tagsAndAttributes)

        self.channelRegistrar.registerCalled = false

        self.channel.editTags { editor in
            editor.add(["foo", "bar"])
            editor.remove(["foo"])
            editor.add(["baz"])
        }

        XCTAssertEqual(["bar", "baz"], self.channel.tags)
        XCTAssertTrue(self.channelRegistrar.registerCalled)
    }

    func testTagsDisabled() throws {
        self.privacyManager.disableFeatures(.tagsAndAttributes)
        self.channelRegistrar.registerCalled = false

        self.channel.tags = ["neat"]
        self.channel.editTags { editor in
            editor.add(["foo", "bar"])
        }

        XCTAssertEqual([], self.channel.tags)
        XCTAssertFalse(self.channelRegistrar.registerCalled)
    }

    func testClearTagsPrivacyManagerDisabled() throws {
        self.privacyManager.enableFeatures(.tagsAndAttributes)
        self.channel.tags = ["neat"]
        self.privacyManager.disableFeatures(.tagsAndAttributes)
        XCTAssertEqual([], self.channel.tags)
    }

    func testNormalizeTags() throws {
        self.privacyManager.enableFeatures(.tagsAndAttributes)

        self.channel.tags = [
            "함",
            "함수 목록",
            " neat ",
            "1",
            "  ",
            "",
            String(repeating: "함", count: 128),
            String(repeating: "g", count: 128),
            String(repeating: "b", count: 129),
        ]

        let expected = [
            "함",
            "함수 목록",
            "neat",
            "1",
            String(repeating: "함", count: 128),
            String(repeating: "g", count: 128),
        ]

        XCTAssertEqual(expected, self.channel.tags)
    }

    @MainActor
    func testChannelCreationFlagDisabled() async throws {
        self.privacyManager.enableFeatures(.tagsAndAttributes)
        self.config.isChannelCreationDelayEnabled = true
        self.channelRegistrar.registerCalled = false

        self.channel = createChannel()
        XCTAssertFalse(self.channelRegistrar.registerCalled)
    }

    func testEnableChannelCreation() async throws {
        self.privacyManager.enableFeatures(.tagsAndAttributes)
        self.config.isChannelCreationDelayEnabled = true
        self.channelRegistrar.registerCalled = false

        self.channel = await createChannel()
        self.channel.enableChannelCreation()
        XCTAssertTrue(self.channelRegistrar.registerCalled)
    }

    func testCRAPayload() async throws {
        self.privacyManager.enableFeatures(.all)
        
        let locationPermission = TestPermissionsDelegate()
        locationPermission.permissionStatus = .granted
        
        let notificationPermission = TestPermissionsDelegate()
        notificationPermission.permissionStatus = .denied
        
        self.permissionsManager.setDelegate(locationPermission, permission: .location)
        self.permissionsManager.setDelegate(notificationPermission, permission: .displayNotifications)

        self.channel.tags = ["foo", "bar"]
        var expectedPayload = ChannelRegistrationPayload()
        expectedPayload.channel.language =
            Locale.autoupdatingCurrent.getLanguageCode()
        expectedPayload.channel.country = Locale.autoupdatingCurrent.regionCode
        expectedPayload.channel.timeZone =
            TimeZone.autoupdatingCurrent.identifier
        expectedPayload.channel.tags = ["foo", "bar"]
        expectedPayload.channel.appVersion = AirshipUtils.bundleShortVersionString()
        expectedPayload.channel.sdkVersion = AirshipVersion.version
        expectedPayload.channel.deviceOS = await UIDevice.current.systemVersion
        expectedPayload.channel.deviceModel = AirshipUtils.deviceModelName()
        expectedPayload.channel.carrier = AirshipUtils.carrierName()
        expectedPayload.channel.setTags = true
        expectedPayload.channel.permissions = [
            "location": "granted",
            "display_notifications": "denied"
        ]

        let payload = await self.channelRegistrar.channelPayload
        XCTAssertEqual(expectedPayload, payload)
    }
    
    func testCRAPayloadPermissionOnNoFeature() async throws {
        self.privacyManager.enableFeatures(.all)
        self.privacyManager.disableFeatures(.tagsAndAttributes)
        
        let locationPermission = TestPermissionsDelegate()
        locationPermission.permissionStatus = .granted
        
        let notificationPermission = TestPermissionsDelegate()
        notificationPermission.permissionStatus = .denied
        
        self.permissionsManager.setDelegate(locationPermission, permission: .location)
        self.permissionsManager.setDelegate(notificationPermission, permission: .displayNotifications)

        self.channel.tags = ["foo", "bar"]
        var expectedPayload = ChannelRegistrationPayload()
        expectedPayload.channel.language =
            Locale.autoupdatingCurrent.getLanguageCode()
        expectedPayload.channel.country = Locale.autoupdatingCurrent.regionCode
        expectedPayload.channel.timeZone =
            TimeZone.autoupdatingCurrent.identifier
        expectedPayload.channel.tags = []
        expectedPayload.channel.appVersion = AirshipUtils.bundleShortVersionString()
        expectedPayload.channel.sdkVersion = AirshipVersion.version
        expectedPayload.channel.deviceOS = await UIDevice.current.systemVersion
        expectedPayload.channel.deviceModel = AirshipUtils.deviceModelName()
        expectedPayload.channel.carrier = AirshipUtils.carrierName()
        expectedPayload.channel.setTags = true
        expectedPayload.channel.permissions = nil

        let payload = await self.channelRegistrar.channelPayload
        XCTAssertEqual(expectedPayload, payload)
    }
    
    func testCRAPayloadMinify() async throws {
        self.privacyManager.enableFeatures(.all)
        
        let locationPermission = TestPermissionsDelegate()
        locationPermission.permissionStatus = .granted
        
        let notificationPermission = TestPermissionsDelegate()
        notificationPermission.permissionStatus = .denied
        
        self.permissionsManager.setDelegate(locationPermission, permission: .location)
        self.permissionsManager.setDelegate(notificationPermission, permission: .displayNotifications)

        self.channel.tags = ["foo", "bar"]
        var expectedPayload = ChannelRegistrationPayload()
        expectedPayload.channel.language =
            Locale.autoupdatingCurrent.getLanguageCode()
        expectedPayload.channel.country = Locale.autoupdatingCurrent.regionCode
        expectedPayload.channel.timeZone =
            TimeZone.autoupdatingCurrent.identifier
        expectedPayload.channel.tags = ["foo", "bar"]
        expectedPayload.channel.appVersion = AirshipUtils.bundleShortVersionString()
        expectedPayload.channel.sdkVersion = AirshipVersion.version
        expectedPayload.channel.deviceOS = await UIDevice.current.systemVersion
        expectedPayload.channel.deviceModel = AirshipUtils.deviceModelName()
        expectedPayload.channel.carrier = AirshipUtils.carrierName()
        expectedPayload.channel.setTags = true
        expectedPayload.channel.permissions = [
            "location": "granted",
            "display_notifications": "denied"
        ]

        let payload = await self.channelRegistrar.channelPayload
        XCTAssertEqual(expectedPayload, payload)
        
        notificationPermission.permissionStatus = .granted
        
        let minimized = await self.channelRegistrar.channelPayload.minimizePayload(previous: payload)
        var expectedMinimized = ChannelRegistrationPayload()
        expectedMinimized.channel.permissions = [
            "display_notifications": "granted",
            "location": "granted",
        ]
        XCTAssertEqual(expectedMinimized, minimized)
    }

    func testCRAPayloadDisabledDeviceTags() async throws {
        self.privacyManager.enableFeatures(.all)
        self.channel.isChannelTagRegistrationEnabled = false
        self.channel.tags = ["foo", "bar"]

        var expectedPayload = ChannelRegistrationPayload()
        expectedPayload.channel.language =
            Locale.autoupdatingCurrent.getLanguageCode()
        expectedPayload.channel.country = Locale.autoupdatingCurrent.regionCode
        expectedPayload.channel.timeZone =
            TimeZone.autoupdatingCurrent.identifier
        expectedPayload.channel.appVersion = AirshipUtils.bundleShortVersionString()
        expectedPayload.channel.sdkVersion = AirshipVersion.version
        expectedPayload.channel.deviceOS = await UIDevice.current.systemVersion
        expectedPayload.channel.deviceModel = AirshipUtils.deviceModelName()
        expectedPayload.channel.carrier = AirshipUtils.carrierName()
        expectedPayload.channel.setTags = false
        expectedPayload.channel.permissions = [:]

        let payload = await self.channelRegistrar.channelPayload
        XCTAssertEqual(expectedPayload, payload)
    }

    func testCRAPayloadPrivacyManagerDisabled() async throws {
        var expectedPayload = ChannelRegistrationPayload()
        expectedPayload.channel.setTags = true
        expectedPayload.channel.tags = []

        let payload = await self.channelRegistrar.channelPayload
        XCTAssertEqual(expectedPayload, payload)
    }

    func testExtendingCRAPayload() async throws {
        self.privacyManager.enableFeatures(.all)

        self.channel.addRegistrationExtender { payload in
            var payload = payload
            payload.channel.pushAddress = "WHAT"
            return payload
        }

        self.channel.addRegistrationExtender { payload in
            var payload = payload
            payload.channel.pushAddress = "OK"
            return payload
        }


        let payload = await self.channelRegistrar.channelPayload
        XCTAssertEqual("OK", payload.channel.pushAddress)
    }

    func testApplicationDidTransitionToForeground() throws {
        self.privacyManager.enableFeatures(.all)
        self.channelRegistrar.registerCalled = false

        self.notificationCenter.post(
            name: AppStateTracker.didTransitionToForeground,
            object: nil
        )

        XCTAssertTrue(self.channelRegistrar.registerCalled)
    }

    func testExistingChannelCreatedNotification() throws {
        self.privacyManager.enableFeatures(.all)

        let expectedUserInfo: [String: Any] = [
            AirshipNotifications.ChannelCreated.isExistingChannelKey: true,
             AirshipNotifications.ChannelCreated.channelIDKey: "someChannelID",
        ]

        let expectation = self.expectation(description: "Notification received")
        self.notificationCenter.addObserver(
            forName: AirshipNotifications.ChannelCreated.name,
            object: nil,
            queue: nil
        ) { notification in
            XCTAssertEqual(
                expectedUserInfo as NSDictionary,
                notification.userInfo! as NSDictionary
            )
            expectation.fulfill()
        }

        self.channelRegistrar.updatesSubject.send(
            .created(
                channelID: "someChannelID",
                isExisting: true
            )
        )

        self.waitForExpectations(timeout: 10)
    }

    func testNewChannelCreatedNotification() throws {
        self.privacyManager.enableFeatures(.all)

        let expectedUserInfo: [String: Any] = [
            AirshipNotifications.ChannelCreated.isExistingChannelKey: false,
             AirshipNotifications.ChannelCreated.channelIDKey: "someChannelID",
        ]

        let expectation = self.expectation(description: "Notification received")
        self.notificationCenter.addObserver(
            forName: AirshipNotifications.ChannelCreated.name,
            object: nil,
            queue: nil
        ) { notification in
            XCTAssertEqual(
                expectedUserInfo as NSDictionary,
                notification.userInfo! as NSDictionary
            )
            expectation.fulfill()
        }

        self.channelRegistrar.updatesSubject.send(
            .created(
                channelID: "someChannelID",
                isExisting: false
            )
        )

        self.waitForExpectations(timeout: 10)
    }

    func testIdentifierUpdates() async throws {
        var updates = self.channel.identifierUpdates.makeAsyncIterator()

        self.privacyManager.enableFeatures(.all)


        self.channelRegistrar.updatesSubject.send(
            .created(
                channelID: "someChannelID",
                isExisting: false
            )
        )

        self.channelRegistrar.updatesSubject.send(
            .created(
                channelID: "someOtherChannelID",
                isExisting: false
            )
        )

        var value = await updates.next()
        XCTAssertEqual("someChannelID", value)
        value = await updates.next()
        XCTAssertEqual("someOtherChannelID", value)
    }

    func testIdentifierUpdatesDeduping() async throws {
        self.channelRegistrar.channelID = "someChannelID"

        var updates = self.channel.identifierUpdates.makeAsyncIterator()

        self.privacyManager.enableFeatures(.all)


        self.channelRegistrar.updatesSubject.send(
            .created(
                channelID: "someChannelID",
                isExisting: false
            )
        )

        self.channelRegistrar.updatesSubject.send(
            .created(
                channelID: "someChannelID",
                isExisting: false
            )
        )

        self.channelRegistrar.updatesSubject.send(
            .created(
                channelID: "someChannelID",
                isExisting: false
            )
        )


        self.channelRegistrar.updatesSubject.send(
            .created(
                channelID: "someOtherChannelID",
                isExisting: false
            )
        )

        var value = await updates.next()
        XCTAssertEqual("someChannelID", value)
        value = await updates.next()
        XCTAssertEqual("someOtherChannelID", value)
    }

    func testIdentifierUpdateAlreadyCreated() async throws {
        self.channelRegistrar.channelID = "someChannelID"
        var updates = self.channel.identifierUpdates.makeAsyncIterator()

        self.privacyManager.enableFeatures(.all)

        self.channelRegistrar.updatesSubject.send(
            .created(
                channelID: "someOtherChannelID",
                isExisting: false
            )
        )

        var value = await updates.next()
        XCTAssertEqual("someChannelID", value)
        value = await updates.next()
        XCTAssertEqual("someOtherChannelID", value)
    }


    func testCreatedIdentifierPassedToAudienceManager() throws {
        self.channelRegistrar.updatesSubject.send(
            .created(
                channelID: "foo",
                isExisting: true
            )
        )

        let expectation = self.expectation(description: "Notification received")

        self.notificationCenter.addObserver(
            forName: AirshipNotifications.ChannelCreated.name,
            object: nil,
            queue: nil
        ) { notification in
            expectation.fulfill()
        }

        self.waitForExpectations(timeout: 10)
        XCTAssertEqual("foo", self.audienceManager.channelID)
    }

    func testInitialIdentifierPassedToAudienceManager() async throws {
        self.channelRegistrar.channelID = "foo"
        self.channel = await createChannel()
        XCTAssertEqual("foo", self.audienceManager.channelID)
    }

    func testLocaleUpdated() throws {
        self.privacyManager.enableFeatures(.all)
        self.channelRegistrar.registerCalled = false

        self.notificationCenter.post(
            name: AirshipNotifications.LocaleUpdated.name,
            object: nil
        )

        XCTAssertTrue(self.channelRegistrar.registerCalled)
    }

    func testConfigUpdate() throws {
        self.channelRegistrar.channelID = "foo"
        self.privacyManager.enableFeatures(.all)
        self.channelRegistrar.registerCalled = false

        self.notificationCenter.post(
            name: RuntimeConfig.configUpdatedEvent,
            object: nil
        )

        XCTAssertTrue(self.channelRegistrar.registerCalled)
    }

    func testConfigUpdateNoChannelID() throws {
        self.channelRegistrar.channelID = nil
        self.privacyManager.enableFeatures(.all)
        self.channelRegistrar.registerCalled = false

        self.notificationCenter.post(
            name: RuntimeConfig.configUpdatedEvent,
            object: nil
        )

        XCTAssertTrue(self.channelRegistrar.registerCalled)
    }

    func testMigratePushTagsToChannelTags() async throws {
        self.privacyManager.enableFeatures(.all)

        self.dataStore.setObject(["cool", "rad"], forKey: "UAPushTags")
        self.channel = await createChannel()

        XCTAssertEqual(["cool", "rad"], self.channel.tags)
    }

    func testMigratePushTagsToChannelTagsAlreadyMigrated() async throws {
        self.privacyManager.enableFeatures(.all)
        self.channel.tags = ["some-random-value"]

        self.channel = await createChannel()
        XCTAssertEqual(["some-random-value"], self.channel.tags)
    }

    @MainActor
    func testCRAPayloadIsActiveFlagInForeground() async throws {
        self.privacyManager.enableFeatures(.all)
        self.appStateTracker.currentState = .active

        let payload = await self.channelRegistrar.channelPayload
        XCTAssertTrue(payload.channel.isActive)
    }

    @MainActor
    func testCRAPayloadIsActiveFlagInBackground() async throws {
        self.privacyManager.enableFeatures(.all)
        self.appStateTracker.currentState = .background


        let payload = await self.channelRegistrar.channelPayload
        XCTAssertFalse(payload.channel.isActive)
    }
}
