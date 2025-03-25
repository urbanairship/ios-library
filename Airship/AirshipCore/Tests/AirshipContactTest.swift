/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

class AirshipContactTest: XCTestCase {
    private let channel: TestChannel = TestChannel()
    private let apiClient: TestContactSubscriptionListAPIClient = TestContactSubscriptionListAPIClient()
    private let contactChannelsProvider: TestContactChannelsProvider = TestContactChannelsProvider()
    private let apiChannel: TestChannelsListAPIClient = TestChannelsListAPIClient()
    private let notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter(
        notificationCenter: NotificationCenter()
    )
    private let date: UATestDate = UATestDate(offset: 0, dateOverride: Date())
    private let dataStore: PreferenceDataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let audienceOverridesProvider: DefaultAudienceOverridesProvider = DefaultAudienceOverridesProvider()
    private let contactManager: TestContactManager = TestContactManager()
    private var contactQueue: AirshipAsyncSerialQueue!
    private var contact: AirshipContact!
    private var privacyManager: AirshipPrivacyManager!
    private var config: RuntimeConfig = RuntimeConfig.testConfig()
    private var subscriptionProvider: SubscriptionListProviderProtocol!

    override func setUp() async throws {
        self.privacyManager = await AirshipPrivacyManager(
            dataStore: self.dataStore,
            config: self.config,
            defaultEnabledFeatures: .all,
            notificationCenter: self.notificationCenter
        )
        
        self.subscriptionProvider = SubscriptionListProvider(
            audienceOverrides: self.audienceOverridesProvider,
            apiClient: self.apiClient,
            date: self.date,
            privacyManager: self.privacyManager)

        self.channel.identifier = "channel id"
        await setupContact()
        self.contact.airshipReady()
        await self.waitOnContactQueue() // waits for the initial setup task
    }

    @MainActor
    func setupContact()  {
        contactQueue = AirshipAsyncSerialQueue(priority: .high)

        self.contact =  AirshipContact(
            dataStore: self.dataStore,
            config: config,
            channel: self.channel,
            privacyManager: self.privacyManager,
            contactChannelsProvider: self.contactChannelsProvider, 
            subscriptionListProvider: subscriptionProvider,
            date: self.date,
            notificationCenter: self.notificationCenter,
            audienceOverridesProvider: self.audienceOverridesProvider,
            contactManager: self.contactManager,
            serialQueue: contactQueue
        )
    }

    func testMigrateNamedUser() async throws {
        await self.verifyOperations([])

        let attributeDate = AirshipDateFormatter.string(fromDate: self.date.now, format: .isoDelimitter)

        let attributePayload = [
            "action": "remove",
            "key": "some-attribute",
            "timestamp": attributeDate
        ]

        let attributeMutation = AttributePendingMutations(mutationsPayload: [
            attributePayload
        ])
        let attributeData = try! NSKeyedArchiver.archivedData(
            withRootObject: [attributeMutation],
            requiringSecureCoding: true
        )

        dataStore.setObject(
            attributeData,
            forKey: AirshipContact.legacyPendingAttributesKey
        )

        let tagMutation = TagGroupsMutation(
            adds: ["some-group": Set(["tag"])],
            removes: nil,
            sets: nil
        )
        let tagData = try! NSKeyedArchiver.archivedData(
            withRootObject: [tagMutation],
            requiringSecureCoding: true
        )
        dataStore.setObject(tagData, forKey: AirshipContact.legacyPendingTagGroupsKey)

        self.dataStore.setObject(
            "named-user",
            forKey: AirshipContact.legacyNamedUserKey
        )

        await setupContact()

        await verifyOperations(
            [
                .identify("named-user"),
                .update(
                    tagUpdates: [ TagGroupUpdate(group: "some-group", tags: ["tag"], type: .add) ],
                    attributeUpdates: [ AttributeUpdate.remove(attribute: "some-attribute", date: AirshipDateFormatter.date(fromISOString: attributeDate)!) ],
                    subscriptionListsUpdates: nil
                )
            ]
        )
    }

    /// Test skip calling identify on the legacy named user if we already have contact data
    func testSkipMigrateLegacyNamedUser() async throws {
        let tagMutation = TagGroupsMutation(
            adds: ["some-group": Set(["tag"])],
            removes: nil,
            sets: nil
        )
        let tagData = try! NSKeyedArchiver.archivedData(
            withRootObject: [tagMutation],
            requiringSecureCoding: true
        )
        dataStore.setObject(tagData, forKey: AirshipContact.legacyPendingTagGroupsKey)

        self.dataStore.setObject(
            "named-user",
            forKey: AirshipContact.legacyNamedUserKey
        )

        await self.contactManager.setCurrentContactIDInfo(
            ContactIDInfo(contactID: "some contact ID", isStable: false, namedUserID: nil)
        )

        await setupContact()

        let _ = await contact.namedUserID

        await verifyOperations(
            [
                .update(
                    tagUpdates: [ TagGroupUpdate(group: "some-group", tags: ["tag"], type: .add) ],
                    attributeUpdates: nil,
                    subscriptionListsUpdates: nil
                )
            ]
        )
    }

    @MainActor
    func testChannelCreatedEnqueuesUpdateTask() async throws {
        notificationCenter.post(
            name: AirshipNotifications.ChannelCreated.name
        )

        await verifyOperations([.resolve])
    }

    func testStableVerifiedContactID() async throws {
        await self.contactManager.setCurrentContactIDInfo(
            ContactIDInfo(contactID: "some-contact-id", isStable: false, namedUserID: nil)
        )

        let contactManager = self.contactManager
        let channel = self.channel
        let date = self.date.now

        let payloadTaskStarted = self.expectation(description: "payload task started")

        let payloadTask = Task {
            payloadTaskStarted.fulfill()
            return await channel.channelPayload
        }

        await fulfillment(of: [payloadTaskStarted])
        await contactManager.setCurrentContactIDInfo(
            ContactIDInfo(
                contactID: "some-other-contact-id",
                isStable: false,
                namedUserID: nil,
                resolveDate: date.advanced(by: -AirshipContact.defaultVerifiedContactIDAge)
            )
        )

        await contactManager.setCurrentContactIDInfo(
            ContactIDInfo(
                contactID: "some-stable-contact-id",
                isStable: true,
                namedUserID: nil,
                resolveDate: date.advanced(by: -AirshipContact.defaultVerifiedContactIDAge)
            )
        )
        await contactManager.setCurrentContactIDInfo(
            ContactIDInfo(contactID: "some-stable-verified-contact-id", isStable: true, namedUserID: nil, resolveDate: date)
        )

        let payload = await payloadTask.value
        XCTAssertEqual("some-stable-verified-contact-id", payload.channel.contactID)
        await verifyOperations([.verify(date)])
    }

    func testStableVerifiedContactIDAlreadyUpToDate() async throws {
        let date = self.date.now

        await self.contactManager.setCurrentContactIDInfo(
            ContactIDInfo(contactID: "some-contact-id", isStable: true, namedUserID: nil, resolveDate: date)
        )

        let channel = self.channel

        let payload = await channel.channelPayload
        XCTAssertEqual("some-contact-id", payload.channel.contactID)
        await verifyOperations([])
    }

    func testMaxAgeStableVerifiedContactID() async throws {
        await self.config.updateRemoteConfig(
            RemoteConfig(
                contactConfig: .init(
                    foregroundIntervalMilliseconds: nil,
                    channelRegistrationMaxResolveAgeMilliseconds: 1000
                )
            )
        )

        let date = self.date.now

        await self.contactManager.setCurrentContactIDInfo(
            ContactIDInfo(contactID: "some-contact-id", isStable: true, namedUserID: nil, resolveDate: date.advanced(by: -1))
        )

        let contactManager = self.contactManager
        let channel = self.channel

        let payloadTaskStarted = self.expectation(description: "payload task started")

        let payloadTask = Task {
            payloadTaskStarted.fulfill()
            return await channel.channelPayload
        }

        await fulfillment(of: [payloadTaskStarted])

        await contactManager.setCurrentContactIDInfo(
            ContactIDInfo(contactID: "some-stable-verified-contact-id", isStable: true, namedUserID: nil, resolveDate: date)
        )

        let payload = await payloadTask.value
        XCTAssertEqual("some-stable-verified-contact-id", payload.channel.contactID)
        await verifyOperations([.verify(date)])
    }

    func testExtendRegistrationPaylaodOnChannelCreate() async throws {
        self.channel.identifier = nil
        await self.contactManager.setCurrentContactIDInfo(
            ContactIDInfo(contactID: "some-contact-id", isStable: false, namedUserID: nil)
        )
        XCTAssertEqual(1, self.channel.extenders.count)
        let payload = await self.channel.channelPayload
        XCTAssertEqual("some-contact-id", payload.channel.contactID)
    }

    func testForegroundResolves() async throws {
        notificationCenter.post(
            name: AppStateTracker.didBecomeActiveNotification
        )

        await verifyOperations([.resolve])
    }

    func testRefreshContactChannelsOnActive() async throws {
        notificationCenter.post(
            name: AppStateTracker.didBecomeActiveNotification
        )

        XCTAssertTrue(contactChannelsProvider.refreshedCalled)
    }

    @MainActor
    func testRefreshContactChannelsOnPush() async throws {
        _ = await self.contact.receivedRemoteNotification(
            try! AirshipJSON.wrap(
                [
                    "com.urbanairship.contact.update": NSNumber(value: true)
                ]
            )
        )

        XCTAssertTrue(contactChannelsProvider.refreshedCalled)
    }

    func testForegroundSkipsResolves() async throws {
        notificationCenter.post(
            name: AppStateTracker.didBecomeActiveNotification
        )

        await verifyOperations([.resolve])

        // Default is 60 seconds
        self.date.offset += AirshipContact.defaultForegroundResolveInterval - 1.0

        notificationCenter.post(
            name: AppStateTracker.didBecomeActiveNotification
        )

        await verifyOperations([.resolve])

        self.date.offset += 1

        notificationCenter.post(
            name: AppStateTracker.didBecomeActiveNotification
        )

        await verifyOperations([.resolve, .resolve])
    }

    func testForegroundSkipsResolvesConfigValue() async throws {
        await self.config.updateRemoteConfig(
            RemoteConfig(
                contactConfig: .init(
                    foregroundIntervalMilliseconds: 1000,
                    channelRegistrationMaxResolveAgeMilliseconds: nil
                )
            )
        )

        notificationCenter.post(
            name: AppStateTracker.didBecomeActiveNotification
        )

        await verifyOperations([.resolve])

        self.date.offset += 0.5

        notificationCenter.post(
            name: AppStateTracker.didBecomeActiveNotification
        )

        await verifyOperations([.resolve])

        self.date.offset += 0.5

        notificationCenter.post(
            name: AppStateTracker.didBecomeActiveNotification
        )

        await verifyOperations([.resolve, .resolve])
    }

    func testIdentify() async throws {
        self.contact.identify("cool user 1")
        await self.verifyOperations([.identify("cool user 1")])
    }

    func testReset() async throws {
        self.contact.reset()
        await self.verifyOperations([.reset])
    }


    func testRegisterEmail() async throws {
        let options = EmailRegistrationOptions.options(
            transactionalOptedIn: Date(),
            properties: ["interests": "newsletter"],
            doubleOptIn: true
        )
        self.contact.registerEmail(
            "ua@airship.com",
            options: options
        )

        await self.verifyOperations([.registerEmail(address: "ua@airship.com", options: options)])
    }

    func testRegisterSMS() async throws {
        let options = SMSRegistrationOptions.optIn(senderID: "28855")
        self.contact.registerSMS(
            "15035556789",
            options: options
        )

        await self.verifyOperations([.registerSMS(msisdn: "15035556789", options: options)])
    }

    func testRegisterOpen() async throws {
        let options = OpenRegistrationOptions.optIn(
            platformName: "my_platform",
            identifiers: ["model": "4"]
        )

        self.contact.registerOpen(
            "open_address",
            options: options
        )

        await self.verifyOperations([.registerOpen(address: "open_address", options: options)])
    }

    func testAssociateChannel() async throws {
        self.contact.associateChannel(
            "some-channel-id",
            type: .email
        )
        await self.verifyOperations([.associateChannel(
            channelID: "some-channel-id",
            channelType: .email
        )])
    }

    func testEdits() async throws {
        self.contact.editTagGroups() { editor in
            editor.add(["neat"], group: "cool")
        }

        self.contact.editAttributes() { editor in
            editor.set(int: 1, attribute: "one")
        }

        self.contact.editSubscriptionLists() { editor in
            editor.subscribe("some id", scope: .app)
        }
    }

    @MainActor
    func testResolveSkippedContactsDisabled() async throws {
        self.privacyManager.disableFeatures(.contacts)
        notificationCenter.post(name: AirshipNotifications.ChannelCreated.name)
        await self.verifyOperations([.reset])
    }

    @MainActor
    func testTagsAndAttributesSkippedContactsDisabled() async throws {
        self.privacyManager.disableFeatures(.contacts)

        self.contact.editTagGroups() { editor in
            editor.add(["neat"], group: "cool")
        }

        self.contact.editAttributes() { editor in
            editor.set(int: 1, attribute: "one")
        }

        self.contact.editSubscriptionLists() { editor in
            editor.subscribe("some id", scope: .app)
        }

        await self.verifyOperations([.reset])
    }

    @MainActor
    func testIdentifySkippedContactsDisabled() async throws {
        self.privacyManager.disableFeatures(.contacts)
        await self.verifyOperations([.reset])
        self.contact.identify("cat")
        await self.verifyOperations([.reset])
    }

    @MainActor
    func testResetOnDisableContacts() async throws {
        self.privacyManager.disableFeatures(.contacts)
        await self.verifyOperations([.reset])
    }

    func testFetchSubscriptionLists() async throws {
        await self.contactManager.setCurrentContactIDInfo(
            ContactIDInfo(contactID: "some-contact-id", isStable: true, namedUserID: nil)
        )

        let apiResult: [String: [ChannelScope]] = ["neat": [.web]]
        let expected = apiResult
        self.apiClient.fetchSubscriptionListsCallback = {
            identifier in
            XCTAssertEqual("some-contact-id", identifier)
            return AirshipHTTPResponse(
                result: apiResult,
                statusCode: 200,
                headers: [:]
            )
        }

        let lists:[String: [ChannelScope]] = try await self.contact.fetchSubscriptionLists()
        XCTAssertEqual(expected, lists)
    }

    func testFetchSubscriptionListsCached() async throws {
        await self.contactManager.setCurrentContactIDInfo(
            ContactIDInfo(contactID: "some-contact-id", isStable: true, namedUserID: nil)
        )

        var apiResult: [String: [ChannelScope]] = ["neat": [.web]]
        var expected = apiResult
        self.apiClient.fetchSubscriptionListsCallback = {
            identifier in
            XCTAssertEqual("some-contact-id", identifier)
            return AirshipHTTPResponse(
                result: apiResult,
                statusCode: 200,
                headers: [:]
            )
        }

        // Populate cache
        var lists: [String: [ChannelScope]] = try await self.contact.fetchSubscriptionLists()

        XCTAssertEqual(expected, lists)

        apiResult = ["something else": [.web]]

        lists = try await self.contact.fetchSubscriptionLists()
        XCTAssertEqual(expected, lists)

        self.date.offset += 599  // 1 second before cache should invalidate
        lists = try await self.contact.fetchSubscriptionLists()
        XCTAssertEqual(expected, lists)

        self.date.offset += 1

        // From api
        expected = apiResult
        lists = try await self.contact.fetchSubscriptionLists()
        XCTAssertEqual(expected, lists)
    }
    
    func testFetchSubscriptionListsReset() async throws {
        await self.contactManager.setCurrentContactIDInfo(
            ContactIDInfo(contactID: "some-contact-id", isStable: true, namedUserID: nil)
        )

        var apiResult: [String: [ChannelScope]] = ["neat": [.web]]
        var expected = apiResult
        self.apiClient.fetchSubscriptionListsCallback = {
            identifier in
            XCTAssertEqual("some-contact-id", identifier)
            return AirshipHTTPResponse(
                result: apiResult,
                statusCode: 200,
                headers: [:]
            )
        }

        // Populate cache
        var lists: [String: [ChannelScope]] = try await self.contact.fetchSubscriptionLists()

        XCTAssertEqual(expected, lists)

        apiResult = ["something else": [.web]]
        
        lists = try await self.contact.fetchSubscriptionLists()
        XCTAssertEqual(expected, lists)

        await subscriptionProvider.refresh()
        
        lists = try await self.contact.fetchSubscriptionLists()
        expected = apiResult
        XCTAssertEqual(expected, lists)
    }

    @MainActor
    func testFetchSubscriptionListsCachedDifferentContactID() async throws {
        await self.contactManager.setCurrentContactIDInfo(
            ContactIDInfo(contactID: "some-contact-id", isStable: true, namedUserID: nil)
        )

        var apiResult: [String: [ChannelScope]] = ["neat": [ChannelScope.web]]
        var expected = apiResult
        self.apiClient.fetchSubscriptionListsCallback = {
            identifier in
            XCTAssertEqual("some-contact-id", identifier)
            return AirshipHTTPResponse(
                result: apiResult,
                statusCode: 200,
                headers: [:]
            )
        }

        // Populate cache
        var lists:[String: [ChannelScope]] = try await self.contact.fetchSubscriptionLists()
        XCTAssertEqual(expected, lists)

        apiResult = ["something else": [.web]]

        // From cache
        lists = try await self.contact.fetchSubscriptionLists()
        XCTAssertEqual(expected, lists)


        // Resolve a new contact ID
        await self.contactManager.setCurrentContactIDInfo(
            ContactIDInfo(contactID: "some-other-contact-id", isStable: true, namedUserID: nil)
        )

        self.apiClient.fetchSubscriptionListsCallback = {
            identifier in
            XCTAssertEqual("some-other-contact-id", identifier)
            return AirshipHTTPResponse(
                result: apiResult,
                statusCode: 200,
                headers: [:]
            )
        }

        // From api
        expected = apiResult
        lists = try await self.contact.fetchSubscriptionLists()
        XCTAssertEqual(expected, lists)
    }

    func testFetchWaitsForStableContactID() async throws {
        await self.contactManager.setCurrentContactIDInfo(
            ContactIDInfo(contactID: "some-contact-id", isStable: false, namedUserID: nil)
        )

        let apiResult: [String: [ChannelScope]] = ["neat": [.web]]
        let expected = apiResult
        self.apiClient.fetchSubscriptionListsCallback = {
            identifier in
            XCTAssertEqual("some-stable-contact-id", identifier)
            return AirshipHTTPResponse(
                result: apiResult,
                statusCode: 200,
                headers: [:]
            )
        }

        let contactManager = self.contactManager

        DispatchQueue.main.async {
            Task {
                await contactManager.setCurrentContactIDInfo(
                    ContactIDInfo(contactID: "some-other-contact-id", isStable: false, namedUserID: nil)
                )

                await contactManager.setCurrentContactIDInfo(
                    ContactIDInfo(contactID: "some-stable-contact-id", isStable: true, namedUserID: nil)
                )
            }
        }
       
        let lists:[String: [ChannelScope]] = try await self.contact.fetchSubscriptionLists()
        XCTAssertEqual(expected, lists)
    }

    func testNotifyRemoteLogin() async throws {
        self.contact.notifyRemoteLogin()
        await verifyOperations([.verify(self.date.now, required: true)])
    }

    func testFetchSubscriptionListsOverrides() async throws {
        await self.contactManager.setCurrentContactIDInfo(
            ContactIDInfo(contactID: "some-contact-id", isStable: true, namedUserID: nil)
        )

        let apiResult: [String: [ChannelScope]] = ["neat": [.web, .app]]
        self.apiClient.fetchSubscriptionListsCallback = {
            identifier in
            XCTAssertEqual("some-contact-id", identifier)
            return AirshipHTTPResponse(
                result: apiResult,
                statusCode: 200,
                headers: [:]
            )
        }

        /// Local history
        await self.audienceOverridesProvider.contactUpdated(
            contactID: "some-contact-id",
            tags: nil,
            attributes: nil,
            subscriptionLists: [
                ScopedSubscriptionListUpdate(listId: "neat", type: .unsubscribe, scope: .web, date: self.date.now)
            ], channels: []
        )

        // Pending
        await self.contactManager.setPendingAudienceOverrides(
            ContactAudienceOverrides(
                subscriptionLists: [
                    ScopedSubscriptionListUpdate(listId: "neat", type: .subscribe, scope: .sms, date: self.date.now)
                ]
            ))

        let lists:[String: [ChannelScope]] = try await self.contact.fetchSubscriptionLists()
        XCTAssertEqual(["neat": [.app, .sms]], lists)
    }

    func testFetchSubscriptionListsFails() async throws {
        await self.contactManager.setCurrentContactIDInfo(
            ContactIDInfo(contactID: "some-contact-id", isStable: true, namedUserID: nil)
        )

        self.apiClient.fetchSubscriptionListsCallback = {
            identifier in
            XCTAssertEqual("some-contact-id", identifier)
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 400,
                headers: [:]
            )
        }

        do {
            let _ = try await self.contact.fetchSubscriptionLists()
            XCTFail("Should throw")
        } catch {}
    }

    func testAudienceOverrides() async throws {
        let update = ContactAudienceUpdate(
            contactID: "some-contact-id",
            tags:  [
                TagGroupUpdate(group: "some group", tags: ["tag"], type: .add)
            ],
            attributes: [
                AttributeUpdate(attribute: "some attribute", type: .set, jsonValue: .string("cool"), date: self.date.now)
            ],
            subscriptionLists: [
                ScopedSubscriptionListUpdate(listId: "some list", type: .unsubscribe, scope: .app, date: self.date.now)
            ], contactChannels: []
        )

        let pending = ContactAudienceOverrides(
            tags:  [
                TagGroupUpdate(group: "some other group", tags: ["tag"], type: .add)
            ],
            attributes: [
                AttributeUpdate(attribute: "some other attribute", type: .set, jsonValue: .string("cool"), date: self.date.now)
            ],
            subscriptionLists: [
                ScopedSubscriptionListUpdate(listId: "some other list", type: .unsubscribe, scope: .app, date: self.date.now)
            ]
        )

        await self.contactManager.setPendingAudienceOverrides(pending)
        await self.contactManager.dispatchAudienceUpdate(update)

        let overrides = await self.audienceOverridesProvider.contactOverrides(contactID: "some-contact-id")
        XCTAssertEqual(overrides.tags, update.tags! + pending.tags)
        XCTAssertEqual(overrides.attributes, update.attributes! + pending.attributes)
        XCTAssertEqual(overrides.subscriptionLists, update.subscriptionLists! + pending.subscriptionLists)
    }

    func testAudienceOverridesStableID() async throws {
        let updateFoo = ContactAudienceUpdate(
            contactID: "foo",
            tags:  [
                TagGroupUpdate(group: "some group", tags: ["tag"], type: .add)
            ],
            attributes: [
                AttributeUpdate(attribute: "some attribute", type: .set, jsonValue: .string("cool"), date: self.date.now)
            ],
            subscriptionLists: [
                ScopedSubscriptionListUpdate(listId: "some list", type: .unsubscribe, scope: .app, date: self.date.now)
            ], contactChannels: []
        )

        let updateBar = ContactAudienceUpdate(
            contactID: "bar",
            tags:  [
                TagGroupUpdate(group: "some other group", tags: ["tag"], type: .add)
            ],
            attributes: [
                AttributeUpdate(attribute: "some other attribute", type: .set, jsonValue: .string("cool"), date: self.date.now)
            ],
            subscriptionLists: [
                ScopedSubscriptionListUpdate(listId: "some other list", type: .unsubscribe, scope: .app, date: self.date.now)
            ], contactChannels: []
        )

        await self.contactManager.dispatchAudienceUpdate(updateFoo)
        await self.contactManager.dispatchAudienceUpdate(updateBar)

        let contactManager = self.contactManager
        Task.detached(priority: .high) {
            await contactManager.setCurrentContactIDInfo(
                ContactIDInfo(contactID: "foo", isStable: false, namedUserID: nil)
            )

            await contactManager.setCurrentContactIDInfo(
                ContactIDInfo(contactID: "bar", isStable: true, namedUserID: nil)
            )
        }

        let overrides = await self.audienceOverridesProvider.contactOverrides()
        XCTAssertEqual(overrides.tags, updateBar.tags)
        XCTAssertEqual(overrides.attributes, updateBar.attributes)
        XCTAssertEqual(overrides.subscriptionLists, updateBar.subscriptionLists)
    }

    @MainActor
    func testGenerateDefaultContactInfo() async throws {
        // Should be called on migrate if no named user ID
        var isCalled = await self.contactManager.generateDefaultContactIDCalled
        XCTAssertTrue(isCalled)

        // Clear it
        await self.contactManager.clearGenerateDefaultContactIDCalledFlag()

        // Trigger it to be called when privacy manager enables contacts
        self.privacyManager.disableFeatures(.all)
        self.privacyManager.enableFeatures(.contacts)
        await self.waitOnContactQueue()

        isCalled = await self.contactManager.generateDefaultContactIDCalled
        XCTAssertTrue(isCalled)
    }

    func testNamedUserID() async throws {
        await self.contactManager.setCurrentNamedUserID("some named user")
        let namedUser = await self.contact.namedUserID
        XCTAssertEqual("some named user", namedUser)
    }

    @MainActor
    func testConflictEvents() async throws {
        let event = ContactConflictEvent(
            tags: [:],
            attributes: [:],
            associatedChannels: [],
            subscriptionLists: [:],
            conflictingNamedUserID: "neat"
        )

        let expectation = XCTestExpectation()
        let subscription = self.contact.conflictEventPublisher.sink { conflict in
            XCTAssertEqual(event, conflict)
            expectation.fulfill()
        }

        self.contactManager.contactUpdatesContinuation.yield(.conflict(event))
        await fulfillment(of: [expectation])
        subscription.cancel()
    }

    @MainActor
    func testConflictEventNotificationCenter() async throws {
        let event = ContactConflictEvent(
            tags: [:],
            attributes: [:],
            associatedChannels: [],
            subscriptionLists: [:],
            conflictingNamedUserID: "neat"
        )

        let expectation = XCTestExpectation()
        self.notificationCenter.addObserver(forName: AirshipNotifications.ContactConflict.name, object: nil, queue: nil) { notification in
            XCTAssertEqual(event, notification.userInfo?[AirshipNotifications.ContactConflict.eventKey] as? ContactConflictEvent)
            expectation.fulfill()
        }

        self.contactManager.contactUpdatesContinuation.yield(.conflict(event))
        await fulfillment(of: [expectation])
    }

    private func verifyOperations(_ operations: [ContactOperation], file: StaticString = #filePath, line: UInt = #line) async {
        let expectation = XCTestExpectation()
        let contactManager = self.contactManager
        let file = file
        let line = line
        self.contactQueue.enqueue {
            let contactOperations = await contactManager.operations
            XCTAssertEqual(operations, contactOperations, file: file, line: line)
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 10.0)
    }

    private func waitOnContactQueue() async {
        let expectation = XCTestExpectation()
        self.contactQueue.enqueue {
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 10.0)
    }

}


fileprivate actor TestContactManager: ContactManagerProtocol {

    private var _currentNamedUserID: String? = nil
    private var _currentContactIDInfo: ContactIDInfo? = nil
    private var _pendingAudienceOverrides = ContactAudienceOverrides()
    private var _onAudienceUpdatedCallback: (@Sendable (ContactAudienceUpdate) async -> Void)?

    let contactUpdates: AsyncStream<ContactUpdate>
    let contactUpdatesContinuation: AsyncStream<ContactUpdate>.Continuation
    let channelUpdates: AsyncStream<[ContactChannel]>
    let channelUpdatesContinuation: AsyncStream<[ContactChannel]>.Continuation

    func validateSMS(_ msisdn: String, sender: String) async throws -> Bool {
        return true
    }

    private(set) var operations: [ContactOperation] = []
    var generateDefaultContactIDCalled: Bool = false

    init() {
        (
            self.contactUpdates,
            self.contactUpdatesContinuation
        ) = AsyncStream<ContactUpdate>.airshipMakeStreamWithContinuation()
        (
            self.channelUpdates,
            self.channelUpdatesContinuation
        ) = AsyncStream<[ContactChannel]>.airshipMakeStreamWithContinuation()
    }

    func onAudienceUpdated(
        onAudienceUpdatedCallback: (@Sendable (AirshipCore.ContactAudienceUpdate) async -> Void)?
    ) {
        self._onAudienceUpdatedCallback = onAudienceUpdatedCallback
    }

    func dispatchAudienceUpdate(_ update: ContactAudienceUpdate) async {
        await self._onAudienceUpdatedCallback!(update)
    }

    func addOperation(_ operation: ContactOperation) {
        operations.append(operation)
    }

    func clearGenerateDefaultContactIDCalledFlag() {
        self.generateDefaultContactIDCalled = false
    }

    func generateDefaultContactIDIfNotSet() {
        generateDefaultContactIDCalled = true
    }

    func setCurrentNamedUserID(_ namedUserID: String) {
        self._currentNamedUserID = namedUserID
        self.contactUpdatesContinuation.yield(.namedUserUpdate(namedUserID))

    }

    func currentNamedUserID() -> String? {
        return self._currentNamedUserID
    }

    func setEnabled(enabled: Bool) {

    }

    func setCurrentContactIDInfo(_ contactIDInfo: ContactIDInfo) {
        self._currentContactIDInfo = contactIDInfo
        self.contactUpdatesContinuation.yield(.contactIDUpdate(contactIDInfo))
    }

    func currentContactIDInfo() -> ContactIDInfo? {
        return _currentContactIDInfo
    }

    func setPendingAudienceOverrides(_ overrides: ContactAudienceOverrides) {
        self._pendingAudienceOverrides = overrides
    }
    func pendingAudienceOverrides(contactID: String) -> ContactAudienceOverrides {
        return self._pendingAudienceOverrides
    }

    func resolveAuth(identifier: String) async throws -> String {
        return ""
    }

    func authTokenExpired(token: String) async {

    }

    func resetIfNeeded() {

        addOperation(.reset)
    }
}
