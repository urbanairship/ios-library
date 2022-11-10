/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

class ChannelTest: XCTestCase {

    private let channelRegistrar = TestChannelRegistrar()
    private let localeManager = TestLocaleManager()
    private let audienceManager = TestChannelAudienceManager()
    private let appStateTracker = TestAppStateTracker()
    private let notificationCenter = NotificationCenter()
    private let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private var config = Config()
    private var privacyManager: PrivacyManager!
    private var channel: Channel!

    override func setUpWithError() throws {


        self.privacyManager = PrivacyManager(dataStore: self.dataStore,
                                             defaultEnabledFeatures: [],
                                             notificationCenter: self.notificationCenter)

        self.channel = createChannel()
    }

    private func createChannel() -> Channel {
        return Channel(dataStore: self.dataStore,
                       config: RuntimeConfig(config: self.config,
                                             dataStore: self.dataStore),
                       privacyManager: self.privacyManager,
                       localeManager: self.localeManager,
                       audienceManager: self.audienceManager,
                       channelRegistrar: self.channelRegistrar,
                       notificationCenter: self.notificationCenter,
                       appStateTracker: self.appStateTracker)
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
            String(repeating: "b", count: 129)
        ]

        let expected = [
            "함",
            "함수 목록",
            "neat",
            "1",
            String(repeating: "함", count: 128),
            String(repeating: "g", count: 128)
        ]

        XCTAssertEqual(expected, self.channel.tags)
    }


    func testChannelCreationFlagDisabled() throws {
        self.privacyManager.enableFeatures(.tagsAndAttributes)
        self.config.isChannelCreationDelayEnabled = true
        self.channelRegistrar.registerCalled = false

        self.channel = createChannel()
        XCTAssertFalse(self.channelRegistrar.registerCalled)
    }

    func testEnableChannelCreation() throws {
        self.privacyManager.enableFeatures(.tagsAndAttributes)
        self.config.isChannelCreationDelayEnabled = true
        self.channelRegistrar.registerCalled = false

        self.channel = createChannel()
        self.channel.enableChannelCreation()
        XCTAssertTrue(self.channelRegistrar.registerCalled)
    }

    func testCRAPayload() throws {
        self.privacyManager.enableFeatures(.all)
        
        self.channel.tags = ["foo", "bar"]
        let expectedPayload = ChannelRegistrationPayload()
        expectedPayload.channel.language = Locale.autoupdatingCurrent.languageCode
        expectedPayload.channel.country = Locale.autoupdatingCurrent.regionCode
        expectedPayload.channel.timeZone = TimeZone.autoupdatingCurrent.identifier
        expectedPayload.channel.tags = ["foo", "bar"]
        expectedPayload.channel.appVersion = Utils.bundleShortVersionString()
        expectedPayload.channel.sdkVersion = AirshipVersion.get()
        expectedPayload.channel.deviceOS = UIDevice.current.systemVersion
        expectedPayload.channel.deviceModel = Utils.deviceModelName()
        expectedPayload.channel.carrier = Utils.carrierName()
        expectedPayload.channel.setTags = true

        let expectation = self.expectation(description: "Created payload")
        self.channel.createChannelPayload { payload in
            XCTAssertEqual(expectedPayload, payload)
            expectation.fulfill()
        }

        self.waitForExpectations(timeout: 10)
    }

    func testCRAPayloadDisabledDeviceTags() throws {
        self.privacyManager.enableFeatures(.all)
        self.channel.isChannelTagRegistrationEnabled = false
        self.channel.tags = ["foo", "bar"]
        
        let expectedPayload = ChannelRegistrationPayload()
        expectedPayload.channel.language = Locale.autoupdatingCurrent.languageCode
        expectedPayload.channel.country = Locale.autoupdatingCurrent.regionCode
        expectedPayload.channel.timeZone = TimeZone.autoupdatingCurrent.identifier
        expectedPayload.channel.appVersion = Utils.bundleShortVersionString()
        expectedPayload.channel.sdkVersion = AirshipVersion.get()
        expectedPayload.channel.deviceOS = UIDevice.current.systemVersion
        expectedPayload.channel.deviceModel = Utils.deviceModelName()
        expectedPayload.channel.carrier = Utils.carrierName()
        expectedPayload.channel.setTags = false

        let expectation = self.expectation(description: "Created payload")
        self.channel.createChannelPayload { payload in
            XCTAssertEqual(expectedPayload, payload)
            expectation.fulfill()
        }

        self.waitForExpectations(timeout: 10)
    }

    func testCRAPayloadPrivacyManagerDisabled() throws {
        let expectedPayload = ChannelRegistrationPayload()
        expectedPayload.channel.setTags = true
        expectedPayload.channel.tags = []

        let expectation = self.expectation(description: "Created payload")
        self.channel.createChannelPayload { payload in
            XCTAssertEqual(expectedPayload, payload)
            expectation.fulfill()
        }

        self.waitForExpectations(timeout: 10)
    }

    func testExtendingCRAPayload() throws {
        self.privacyManager.enableFeatures(.all)

        self.channel.addRegistrationExtender { payload, completionHandler in
            payload.channel.pushAddress = "WHAT"
            completionHandler(payload)
        }

        self.channel.addRegistrationExtender { payload, completionHandler in
            payload.channel.pushAddress = "OK"
            completionHandler(payload)
        }

        let expectation = self.expectation(description: "Created payload")
        self.channel.createChannelPayload { payload in
            XCTAssertEqual("OK", payload.channel.pushAddress)
            expectation.fulfill()
        }

        self.waitForExpectations(timeout: 10)
    }

    func testExtendingCRAPayloadBackgroundQueue() throws {
        self.privacyManager.enableFeatures(.all)

        self.channel.addRegistrationExtender { payload, completionHandler in
            payload.channel.pushAddress = "WHAT"
            completionHandler(payload)
        }

        self.channel.addRegistrationExtender { payload, completionHandler in
            DispatchQueue.global(qos: .userInteractive).async {
                payload.channel.pushAddress = "OK"
                completionHandler(payload)
            }
        }

        let expectation = self.expectation(description: "Created payload")
        self.channel.createChannelPayload { payload in
            XCTAssertEqual("OK", payload.channel.pushAddress)
            expectation.fulfill()
        }

        self.waitForExpectations(timeout: 10)
    }

    func testApplicationDidTransitionToForeground() throws {
        self.privacyManager.enableFeatures(.all)
        self.channelRegistrar.registerCalled = false

        self.notificationCenter.post(name: AppStateTracker.didTransitionToForeground,
                                     object: nil)

        XCTAssertTrue(self.channelRegistrar.registerCalled)
    }

    func testExistingChannelCreatedNotification() throws {
        self.privacyManager.enableFeatures(.all)

        let expectedUserInfo: [String: Any] = [
            Channel.channelExistingKey: true,
            Channel.channelIdentifierKey: "someChannelID"
        ]

        let expectation = self.expectation(description: "Notification received")
        self.notificationCenter.addObserver(forName: Channel.channelCreatedEvent, object: nil, queue: nil) { notification in
            XCTAssertEqual(expectedUserInfo as NSDictionary, notification.userInfo! as NSDictionary)
            expectation.fulfill()
        }

        self.channel.channelCreated(channelID: "someChannelID", existing: true)

        self.waitForExpectations(timeout: 10)
    }

    func testNewChannelCreatedNotification() throws {
        self.privacyManager.enableFeatures(.all)

        let expectedUserInfo: [String: Any] = [
            Channel.channelExistingKey: false,
            Channel.channelIdentifierKey: "someChannelID"
        ]

        let expectation = self.expectation(description: "Notification received")
        self.notificationCenter.addObserver(forName: Channel.channelCreatedEvent, object: nil, queue: nil) { notification in
            XCTAssertEqual(expectedUserInfo as NSDictionary, notification.userInfo! as NSDictionary)
            expectation.fulfill()
        }

        self.channel.channelCreated(channelID: "someChannelID", existing: false)

        self.waitForExpectations(timeout: 10)
    }

    func testChannelUpdated() throws {
        self.privacyManager.enableFeatures(.all)
        self.channelRegistrar.channelID = "someChannelID"

        let expectedUserInfo: [String: Any] = [
            Channel.channelIdentifierKey: "someChannelID"
        ]

        let expectation = self.expectation(description: "Notification received")
        self.notificationCenter.addObserver(forName: Channel.channelUpdatedEvent, object: nil, queue: nil) { notification in
            XCTAssertEqual(expectedUserInfo as NSDictionary, notification.userInfo! as NSDictionary)
            expectation.fulfill()
        }

        self.channel.registrationSucceeded()
        self.waitForExpectations(timeout: 10)
    }

    func testChannelUpdateFailed() throws {
        self.privacyManager.enableFeatures(.all)

        let expectation = self.expectation(description: "Notification received")
        self.notificationCenter.addObserver(forName: Channel.channelRegistrationFailedEvent, object: nil, queue: nil) { notification in
            expectation.fulfill()
        }

        self.channel.registrationFailed()
        self.waitForExpectations(timeout: 10)
    }

    func testCreatedIdentifierPassedToAudienceManager() throws {
        self.channel.channelCreated(channelID: "foo", existing: true)
        XCTAssertEqual("foo", self.audienceManager.channelID)
    }

    func testInitialIdentifierPassedToAudienceManager() throws {
        self.channelRegistrar.channelID = "foo"
        self.channel = createChannel()
        XCTAssertEqual("foo", self.audienceManager.channelID)
    }

    func testLocaleUpdated() throws {
        self.privacyManager.enableFeatures(.all)
        self.channelRegistrar.registerCalled = false

        self.notificationCenter.post(name: LocaleManager.localeUpdatedEvent, object: nil)

        XCTAssertTrue(self.channelRegistrar.registerCalled)
    }

    func testConfigUpdate() throws {
        self.channelRegistrar.channelID = "foo"
        self.privacyManager.enableFeatures(.all)
        self.channelRegistrar.registerCalled = false

        self.notificationCenter.post(name: RuntimeConfig.configUpdatedEvent, object: nil)

        XCTAssertTrue(self.channelRegistrar.fullRegistrationCalled)
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

    func testMigratePushTagsToChannelTags() throws {
        self.privacyManager.enableFeatures(.all)

        self.dataStore.setObject(["cool", "rad"], forKey: "UAPushTags")
        self.channel = createChannel()

        XCTAssertEqual(["cool", "rad"], self.channel.tags)
    }

    func testMigratePushTagsToChannelTagsAlreadyMigrated() throws {
        self.privacyManager.enableFeatures(.all)
        self.channel.tags = ["some-random-value"]

        self.channel = createChannel()
        XCTAssertEqual(["some-random-value"], self.channel.tags)
    }

    func testCRAPayloadIsActiveFlagInForeground() throws {
        self.privacyManager.enableFeatures(.all)
        self.appStateTracker.currentState = .active

        let expectation = self.expectation(description: "Created payload")
        self.channel.createChannelPayload { payload in
            XCTAssertTrue(payload.channel.isActive)
            expectation.fulfill()
        }

        self.waitForExpectations(timeout: 10)
    }

    func testCRAPayloadIsActiveFlagInBackground() throws {
        self.privacyManager.enableFeatures(.all)
        self.appStateTracker.currentState = .background

        let expectation = self.expectation(description: "Created payload")
        self.channel.createChannelPayload { payload in
            XCTAssertFalse(payload.channel.isActive)
            expectation.fulfill()
        }

        self.waitForExpectations(timeout: 10)
    }

    func testForwardContactSubscriptionListUpdates() throws {
        let updates = [
            SubscriptionListUpdate(listId: "bar", type: .subscribe),
            SubscriptionListUpdate(listId: "baz", type: .unsubscribe)
        ]

        self.channel.processContactSubscriptionUpdates(updates)
        XCTAssertEqual(updates, self.audienceManager.contactUpdates)
    }

}
