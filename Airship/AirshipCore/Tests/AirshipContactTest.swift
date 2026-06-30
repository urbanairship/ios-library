/* Copyright Airship and Contributors */

import Testing

@_spi(AirshipInternal) import AirshipBasement
@testable import AirshipCore
import Combine
import Foundation

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct AirshipContactTest {
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
    private let config: RuntimeConfig = RuntimeConfig.testConfig()
    private let privacyManager: DefaultAirshipPrivacyManager
    private let subscriptionProvider: SubscriptionListProviderProtocol

    /// Holds the values that `setupContact()` (re)creates, so they can be
    /// replaced from non-mutating test methods.
    private final class MutableState {
        var contact: DefaultAirshipContact!
        var contactQueue: AirshipAsyncSerialQueue!
    }
    private let state = MutableState()

    private var contact: DefaultAirshipContact! {
        get { state.contact }
        nonmutating set { state.contact = newValue }
    }

    private var contactQueue: AirshipAsyncSerialQueue! {
        get { state.contactQueue }
        nonmutating set { state.contactQueue = newValue }
    }

    init() async throws {
        self.privacyManager = DefaultAirshipPrivacyManager(
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
        setupContact()
        self.contact.airshipReady()
        await self.waitOnContactQueue() // waits for the initial setup task
    }

    @MainActor
    func setupContact()  {
        contactQueue = AirshipAsyncSerialQueue(priority: .high)

        self.contact =  DefaultAirshipContact(
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

    @Test
    func testMigrateNamedUser() async throws {
        await self.verifyOperations([])

        let attributeDate = AirshipDateFormatter.string(fromDate: self.date.now, format: .iso8601WithMilliseconds)

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
            forKey: DefaultAirshipContact.legacyPendingAttributesKey
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
        dataStore.setObject(tagData, forKey: DefaultAirshipContact.legacyPendingTagGroupsKey)

        self.dataStore.setObject(
            "named-user",
            forKey: DefaultAirshipContact.legacyNamedUserKey
        )

        setupContact()

        await verifyOperations(
            [
                .identify("named-user"),
                .update(
                    tagUpdates: [ TagGroupUpdate(group: "some-group", tags: ["tag"], type: .add) ],
                    attributeUpdates: [ AttributeUpdate.remove(attribute: "some-attribute", date: AirshipDateFormatter.date(from: attributeDate)!) ],
                    subscriptionListsUpdates: nil
                )
            ]
        )
    }

    /// Test skip calling identify on the legacy named user if we already have contact data
    @Test
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
        dataStore.setObject(tagData, forKey: DefaultAirshipContact.legacyPendingTagGroupsKey)

        self.dataStore.setObject(
            "named-user",
            forKey: DefaultAirshipContact.legacyNamedUserKey
        )

        await self.contactManager.setCurrentContactIDInfo(
            ContactIDInfo(contactID: "some contact ID", isStable: false, namedUserID: nil)
        )

        setupContact()

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

    @Test
    @MainActor
    func testChannelCreatedEnqueuesUpdateTask() async throws {
        notificationCenter.post(
            name: AirshipNotifications.ChannelCreated.name
        )

        await verifyOperations([.resolve])
    }

    @Test
    func testStableVerifiedContactID() async throws {
        await self.contactManager.setCurrentContactIDInfo(
            ContactIDInfo(contactID: "some-contact-id", isStable: false, namedUserID: nil)
        )

        let contactManager = self.contactManager
        let channel = self.channel
        let date = self.date.now

        let payloadTaskStarted = AirshipTestExpectation(description: "payload task started")

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
                resolveDate: date.advanced(by: -DefaultAirshipContact.defaultVerifiedContactIDAge)
            )
        )

        await contactManager.setCurrentContactIDInfo(
            ContactIDInfo(
                contactID: "some-stable-contact-id",
                isStable: true,
                namedUserID: nil,
                resolveDate: date.advanced(by: -DefaultAirshipContact.defaultVerifiedContactIDAge)
            )
        )

        // Wait until the stale (but stable) contact triggers the verify before
        // supplying the fresh, verified contact info. Otherwise the producer's
        // up-to-date check can be raced by the fresh info and never enqueue the
        // verify operation.
        await waitForOperations([.verify(date)])

        await contactManager.setCurrentContactIDInfo(
            ContactIDInfo(contactID: "some-stable-verified-contact-id", isStable: true, namedUserID: nil, resolveDate: date)
        )

        let payload = await payloadTask.value
        #expect("some-stable-verified-contact-id" == payload.channel.contactID)
        await verifyOperations([.verify(date)])
    }

    @Test
    func testStableVerifiedContactIDAlreadyUpToDate() async throws {
        let date = self.date.now

        await self.contactManager.setCurrentContactIDInfo(
            ContactIDInfo(contactID: "some-contact-id", isStable: true, namedUserID: nil, resolveDate: date)
        )

        let channel = self.channel

        let payload = await channel.channelPayload
        #expect("some-contact-id" == payload.channel.contactID)
        await verifyOperations([])
    }

    @Test
    @MainActor
    func testMaxAgeStableVerifiedContactID() async throws {
        self.config.updateRemoteConfig(
            RemoteConfig(
                contactConfig: .init(
                    foregroundIntervalMilliseconds: nil,
                    channelRegistrationMaxResolveAgeMilliseconds: 1000
                )
            )
        )

        let date = self.date.now

        // Ensure stale age > 1 s max-age to avoid race
        let staleDate = date.advanced(by: -2)

        await self.contactManager.setCurrentContactIDInfo(
            ContactIDInfo(contactID: "some-contact-id", isStable: true, namedUserID: nil, resolveDate: staleDate)
        )

        let contactManager = self.contactManager
        let channel = self.channel

        let payloadTaskStarted = AirshipTestExpectation(description: "payload task started")

        let payloadTask = Task { @MainActor in
            payloadTaskStarted.fulfill()
            return await channel.channelPayload
        }

        await fulfillment(of: [payloadTaskStarted])

        // Wait until the stale contact has triggered the verify before
        // supplying the fresh, verified contact info, so the producer's
        // max-age check can't be raced.
        await waitForOperations([.verify(date)])

        await contactManager.setCurrentContactIDInfo(
            ContactIDInfo(contactID: "some-stable-verified-contact-id", isStable: true, namedUserID: nil, resolveDate: date)
        )

        let payload = await payloadTask.value
        #expect("some-stable-verified-contact-id" == payload.channel.contactID)
        await verifyOperations([.verify(date)])
    }

    @Test
    func testExtendRegistrationPaylaodOnChannelCreate() async throws {
        self.channel.identifier = nil
        await self.contactManager.setCurrentContactIDInfo(
            ContactIDInfo(contactID: "some-contact-id", isStable: false, namedUserID: nil)
        )
        #expect(1 == self.channel.extenders.count)
        let payload = await self.channel.channelPayload
        #expect("some-contact-id" == payload.channel.contactID)
    }

    @Test
    func testExtendRegistrationPayloadGeneratesContactID() async throws {
        self.channel.identifier = nil
        await self.contactManager.clearGenerateDefaultContactIDCalledFlag()
        _ = await self.channel.channelPayload
        let generated = await self.contactManager.generateDefaultContactIDCalled
        #expect(generated)
    }

    @Test
    func testForegroundResolves() async throws {
        notificationCenter.post(
            name: AppStateTracker.didBecomeActiveNotification
        )

        await verifyOperations([.resolve])
    }

    @Test
    func testRefreshContactChannelsOnActive() async throws {
        notificationCenter.post(
            name: AppStateTracker.didBecomeActiveNotification
        )

        #expect(contactChannelsProvider.refreshedCalled)
    }

    @Test
    @MainActor
    func testRefreshContactChannelsOnPush() async throws {
        _ = await self.contact.receivedRemoteNotification(
            try! AirshipJSON.wrap(
                [
                    "com.urbanairship.contact.update": NSNumber(value: true)
                ]
            )
        )

        #expect(contactChannelsProvider.refreshedCalled)
    }

    @Test
    func testForegroundSkipsResolves() async throws {
        notificationCenter.post(
            name: AppStateTracker.didBecomeActiveNotification
        )

        await verifyOperations([.resolve])

        // Default is 60 seconds
        self.date.offset += DefaultAirshipContact.defaultForegroundResolveInterval - 1.0

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

    @Test
    func testForegroundSkipsResolvesConfigValue() async throws {
        self.config.updateRemoteConfig(
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

    @Test
    func testIdentify() async throws {
        self.contact.identify("cool user 1")
        await self.verifyOperations([.identify("cool user 1")])
    }

    @Test
    func testReset() async throws {
        self.contact.reset()
        await self.verifyOperations([.reset])
    }


    @Test
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

    @Test
    func testRegisterSMS() async throws {
        let options = SMSRegistrationOptions.optIn(senderID: "28855")
        self.contact.registerSMS(
            "15035556789",
            options: options
        )

        await self.verifyOperations([.registerSMS(msisdn: "15035556789", options: options)])
    }

    @Test
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

    @Test
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

    @Test
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

    @Test
    @MainActor
    func testResolveSkippedContactsDisabled() async throws {
        self.privacyManager.disableFeatures(.contacts)
        notificationCenter.post(name: AirshipNotifications.ChannelCreated.name)
        await self.verifyOperations([.reset])
    }

    @Test
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

    @Test
    @MainActor
    func testIdentifySkippedContactsDisabled() async throws {
        self.privacyManager.disableFeatures(.contacts)
        await self.verifyOperations([.reset])
        self.contact.identify("cat")
        await self.verifyOperations([.reset])
    }

    @Test
    @MainActor
    func testResetOnDisableContacts() async throws {
        self.privacyManager.disableFeatures(.contacts)
        await self.verifyOperations([.reset])
    }

    @Test
    func testFetchSubscriptionLists() async throws {
        await self.contactManager.setCurrentContactIDInfo(
            ContactIDInfo(contactID: "some-contact-id", isStable: true, namedUserID: nil)
        )

        let apiResult: [String: [ChannelScope]] = ["neat": [.web]]
        let expected = apiResult
        self.apiClient.fetchSubscriptionListsCallback = {
            identifier in
            #expect("some-contact-id" == identifier)
            return AirshipHTTPResponse(
                result: apiResult,
                statusCode: 200,
                headers: [:]
            )
        }

        let lists:[String: [ChannelScope]] = try await self.contact.fetchSubscriptionLists()
        #expect(expected == lists)
    }

    @Test
    func testFetchSubscriptionListsCached() async throws {
        await self.contactManager.setCurrentContactIDInfo(
            ContactIDInfo(contactID: "some-contact-id", isStable: true, namedUserID: nil)
        )

        var apiResult: [String: [ChannelScope]] = ["neat": [.web]]
        var expected = apiResult
        self.apiClient.fetchSubscriptionListsCallback = {
            identifier in
            #expect("some-contact-id" == identifier)
            return AirshipHTTPResponse(
                result: apiResult,
                statusCode: 200,
                headers: [:]
            )
        }

        // Populate cache
        var lists: [String: [ChannelScope]] = try await self.contact.fetchSubscriptionLists()

        #expect(expected == lists)

        apiResult = ["something else": [.web]]

        lists = try await self.contact.fetchSubscriptionLists()
        #expect(expected == lists)

        self.date.offset += 599  // 1 second before cache should invalidate
        lists = try await self.contact.fetchSubscriptionLists()
        #expect(expected == lists)

        self.date.offset += 1

        // From api
        expected = apiResult
        lists = try await self.contact.fetchSubscriptionLists()
        #expect(expected == lists)
    }
    
    @Test
    func testFetchSubscriptionListsReset() async throws {
        await self.contactManager.setCurrentContactIDInfo(
            ContactIDInfo(contactID: "some-contact-id", isStable: true, namedUserID: nil)
        )

        var apiResult: [String: [ChannelScope]] = ["neat": [.web]]
        var expected = apiResult
        self.apiClient.fetchSubscriptionListsCallback = {
            identifier in
            #expect("some-contact-id" == identifier)
            return AirshipHTTPResponse(
                result: apiResult,
                statusCode: 200,
                headers: [:]
            )
        }

        // Populate cache
        var lists: [String: [ChannelScope]] = try await self.contact.fetchSubscriptionLists()

        #expect(expected == lists)

        apiResult = ["something else": [.web]]
        
        lists = try await self.contact.fetchSubscriptionLists()
        #expect(expected == lists)

        await subscriptionProvider.refresh()
        
        lists = try await self.contact.fetchSubscriptionLists()
        expected = apiResult
        #expect(expected == lists)
    }

    @Test
    @MainActor
    func testFetchSubscriptionListsCachedDifferentContactID() async throws {
        await self.contactManager.setCurrentContactIDInfo(
            ContactIDInfo(contactID: "some-contact-id", isStable: true, namedUserID: nil)
        )

        var apiResult: [String: [ChannelScope]] = ["neat": [ChannelScope.web]]
        var expected = apiResult
        self.apiClient.fetchSubscriptionListsCallback = {
            identifier in
            #expect("some-contact-id" == identifier)
            return AirshipHTTPResponse(
                result: apiResult,
                statusCode: 200,
                headers: [:]
            )
        }

        // Populate cache
        var lists:[String: [ChannelScope]] = try await self.contact.fetchSubscriptionLists()
        #expect(expected == lists)

        apiResult = ["something else": [.web]]

        // From cache
        lists = try await self.contact.fetchSubscriptionLists()
        #expect(expected == lists)


        // Resolve a new contact ID
        await self.contactManager.setCurrentContactIDInfo(
            ContactIDInfo(contactID: "some-other-contact-id", isStable: true, namedUserID: nil)
        )

        self.apiClient.fetchSubscriptionListsCallback = {
            identifier in
            #expect("some-other-contact-id" == identifier)
            return AirshipHTTPResponse(
                result: apiResult,
                statusCode: 200,
                headers: [:]
            )
        }

        // From api
        expected = apiResult
        lists = try await self.contact.fetchSubscriptionLists()
        #expect(expected == lists)
    }

    @Test
    func testFetchWaitsForStableContactID() async throws {
        await self.contactManager.setCurrentContactIDInfo(
            ContactIDInfo(contactID: "some-contact-id", isStable: false, namedUserID: nil)
        )

        let apiResult: [String: [ChannelScope]] = ["neat": [.web]]
        let expected = apiResult
        self.apiClient.fetchSubscriptionListsCallback = {
            identifier in
            #expect("some-stable-contact-id" == identifier)
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
        #expect(expected == lists)
    }

    @Test
    func testNotifyRemoteLogin() async throws {
        self.contact.notifyRemoteLogin()
        await verifyOperations([.verify(self.date.now, required: true)])
    }

    @Test
    func testFetchSubscriptionListsOverrides() async throws {
        await self.contactManager.setCurrentContactIDInfo(
            ContactIDInfo(contactID: "some-contact-id", isStable: true, namedUserID: nil)
        )

        let apiResult: [String: [ChannelScope]] = ["neat": [.web, .app]]
        self.apiClient.fetchSubscriptionListsCallback = {
            identifier in
            #expect("some-contact-id" == identifier)
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
        #expect(["neat": [.app, .sms]] == lists)
    }

    @Test
    func testFetchSubscriptionListsFails() async throws {
        await self.contactManager.setCurrentContactIDInfo(
            ContactIDInfo(contactID: "some-contact-id", isStable: true, namedUserID: nil)
        )

        self.apiClient.fetchSubscriptionListsCallback = {
            identifier in
            #expect("some-contact-id" == identifier)
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 400,
                headers: [:]
            )
        }

        do {
            let _ = try await self.contact.fetchSubscriptionLists()
            Issue.record("Should throw")
        } catch {}
    }

    @Test
    func testAudienceOverrides() async throws {
        let update = ContactAudienceUpdate(
            contactID: "some-contact-id",
            tags:  [
                TagGroupUpdate(group: "some group", tags: ["tag"], type: .add)
            ],
            attributes: [
                AttributeUpdate(attribute: "some attribute", type: .set, jsonValue: "cool", date: self.date.now)
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
                AttributeUpdate(attribute: "some other attribute", type: .set, jsonValue: "cool", date: self.date.now)
            ],
            subscriptionLists: [
                ScopedSubscriptionListUpdate(listId: "some other list", type: .unsubscribe, scope: .app, date: self.date.now)
            ]
        )

        await self.contactManager.setPendingAudienceOverrides(pending)
        await self.contactManager.dispatchAudienceUpdate(update)

        let overrides = await self.audienceOverridesProvider.contactOverrides(contactID: "some-contact-id")
        #expect(overrides.tags == update.tags! + pending.tags)
        #expect(overrides.attributes == update.attributes! + pending.attributes)
        #expect(overrides.subscriptionLists == update.subscriptionLists! + pending.subscriptionLists)
    }

    @Test
    func testAudienceOverridesStableID() async throws {
        let updateFoo = ContactAudienceUpdate(
            contactID: "foo",
            tags:  [
                TagGroupUpdate(group: "some group", tags: ["tag"], type: .add)
            ],
            attributes: [
                AttributeUpdate(attribute: "some attribute", type: .set, jsonValue: "cool", date: self.date.now)
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
                AttributeUpdate(attribute: "some other attribute", type: .set, jsonValue: "cool", date: self.date.now)
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
        #expect(overrides.tags == updateBar.tags)
        #expect(overrides.attributes == updateBar.attributes)
        #expect(overrides.subscriptionLists == updateBar.subscriptionLists)
    }

    @Test
    @MainActor
    func testGenerateDefaultContactInfo() async throws {
        // Should be called on migrate if no named user ID
        var isCalled = await self.contactManager.generateDefaultContactIDCalled
        #expect(isCalled)

        // Clear it
        await self.contactManager.clearGenerateDefaultContactIDCalledFlag()

        // Trigger it to be called when privacy manager enables contacts
        self.privacyManager.disableFeatures(.all)
        self.privacyManager.enableFeatures(.contacts)
        await self.waitOnContactQueue()

        isCalled = await self.contactManager.generateDefaultContactIDCalled
        #expect(isCalled)
    }

    @Test
    func testNamedUserID() async throws {
        await self.contactManager.setCurrentNamedUserID("some named user")
        let namedUser = await self.contact.namedUserID
        #expect("some named user" == namedUser)
    }

    @Test
    @MainActor
    func testConflictEvents() async throws {
        let event = ContactConflictEvent(
            tags: [:],
            attributes: [:],
            associatedChannels: [],
            subscriptionLists: [:],
            conflictingNamedUserID: "neat"
        )

        let expectation = AirshipTestExpectation()
        let subscription = self.contact.conflictEventPublisher.sink { conflict in
            #expect(event == conflict)
            expectation.fulfill()
        }

        self.contactManager.contactUpdatesContinuation.yield(.conflict(event))
        await fulfillment(of: [expectation])
        subscription.cancel()
    }

    @Test
    @MainActor
    func testConflictEventNotificationCenter() async throws {
        let event = ContactConflictEvent(
            tags: [:],
            attributes: [:],
            associatedChannels: [],
            subscriptionLists: [:],
            conflictingNamedUserID: "neat"
        )

        let expectation = AirshipTestExpectation()
        self.notificationCenter.addObserver(forName: AirshipNotifications.ContactConflict.name, object: nil, queue: nil) { notification in
            #expect(event == notification.userInfo?[AirshipNotifications.ContactConflict.eventKey] as? ContactConflictEvent)
            expectation.fulfill()
        }

        self.contactManager.contactUpdatesContinuation.yield(.conflict(event))
        await fulfillment(of: [expectation])
    }

    /// Reads the contact manager's operations back through `contactQueue` so the
    /// read stays ordered behind any pending producer work enqueued on the same
    /// queue (operations are appended via `contactQueue`).
    private func currentOperations() async -> [ContactOperation] {
        let contactManager = self.contactManager
        let contactQueue = self.contactQueue!
        let box = ContactOperationsBox()
        let expectation = AirshipTestExpectation()
        contactQueue.enqueue {
            let ops = await contactManager.operations
            box.set(ops)
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 10.0)
        return box.get()
    }

    /// Polls (bounded by `timeout`) until the contact manager reaches the
    /// expected operations, so callers can sequence against asynchronously
    /// produced operations instead of racing the producer.
    @discardableResult
    private func waitForOperations(_ operations: [ContactOperation], timeout: TimeInterval = 10.0) async -> [ContactOperation] {
        let deadline = Date().addingTimeInterval(timeout)
        var contactOperations = await currentOperations()
        while contactOperations != operations, Date() < deadline {
            await Task.yield()
            contactOperations = await currentOperations()
        }
        return contactOperations
    }

    private func verifyOperations(_ operations: [ContactOperation], sourceLocation: SourceLocation = #_sourceLocation) async {
        let contactOperations = await waitForOperations(operations)
        #expect(operations == contactOperations, sourceLocation: sourceLocation)
    }

    private func waitOnContactQueue() async {
        let expectation = AirshipTestExpectation()
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

/// Thread-safe container used to ferry the contact operations read inside a
/// `@Sendable` queue closure back out to the awaiting test.
private final class ContactOperationsBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: [ContactOperation] = []

    func set(_ newValue: [ContactOperation]) {
        lock.withLock { value = newValue }
    }

    func get() -> [ContactOperation] {
        lock.withLock { value }
    }
}
