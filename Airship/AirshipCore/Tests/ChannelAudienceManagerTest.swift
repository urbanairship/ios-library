/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore
import Combine

class ChannelAudienceManagerTest: XCTestCase {

    private let workManager = TestWorkManager()
    private let notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter(
        notificationCenter: NotificationCenter()
    )
    private let date: UATestDate = UATestDate()
    private let dataStore: PreferenceDataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let subscriptionListClient: TestSubscriptionListAPIClient = TestSubscriptionListAPIClient()
    private let updateClient: TestChannelBulkUpdateAPIClient = TestChannelBulkUpdateAPIClient()
    private let audienceOverridesProvider: DefaultAudienceOverridesProvider = DefaultAudienceOverridesProvider()
    private var privacyManager: TestPrivacyManager!
    private var audienceManager: ChannelAudienceManager!

    @MainActor
    override func setUp() async throws {
        self.privacyManager = TestPrivacyManager(
            dataStore: self.dataStore,
            config: RuntimeConfig.testConfig(),
            defaultEnabledFeatures: .all,
            notificationCenter: self.notificationCenter
        )

        self.audienceManager = ChannelAudienceManager(
            dataStore: self.dataStore,
            workManager: self.workManager,
            subscriptionListProvider: ChannelSubscriptionListProvider(
                audienceOverrides: self.audienceOverridesProvider,
                apiClient: self.subscriptionListClient,
                date: self.date
            ),
            updateClient: self.updateClient,
            privacyManager: self.privacyManager,
            notificationCenter: self.notificationCenter,
            date: self.date,
            audienceOverridesProvider: self.audienceOverridesProvider
        )

        self.audienceManager.enabled = true
        self.audienceManager.channelID = "some-channel"

        self.workManager.workRequests.removeAll()
    }

    func testBackgroundWorkRequest() async throws {
        XCTAssertEqual(1, self.workManager.backgroundWorkRequests.count)

        let expected = AirshipWorkRequest(
            workID: ChannelAudienceManager.updateTaskID
        )
        XCTAssertEqual(expected, self.workManager.backgroundWorkRequests.first)
    }

    func testUpdates() async throws {
        let subscriptionListEditor = self.audienceManager
            .editSubscriptionLists()
        subscriptionListEditor.subscribe("pizza")
        subscriptionListEditor.unsubscribe("coffee")
        subscriptionListEditor.apply()

        subscriptionListEditor.subscribe("hotdogs")
        subscriptionListEditor.apply()

        let tagEditor = self.audienceManager.editTagGroups(
            allowDeviceGroup: true
        )
        tagEditor.add(["tag"], group: "some-group")
        tagEditor.apply()

        let attributeEditor = self.audienceManager.editAttributes()
        attributeEditor.set(string: "hello", attribute: "some-attribute")
        attributeEditor.apply()

        let activityUpdate = LiveActivityUpdate(
            action: .set,
            source: .liveActivity(id: "foo", name: "bar", startTimeMS: 10),
            actionTimeMS: 10
        )

        self.audienceManager.addLiveActivityUpdate(activityUpdate)

        XCTAssertEqual(5, self.workManager.workRequests.count)

        let expectation = XCTestExpectation(description: "callback called")

        self.updateClient.updateCallback = { identifier, update in
            expectation.fulfill()
            XCTAssertEqual("some-channel", identifier)
            XCTAssertEqual(3, update.subscriptionListUpdates.count)
            XCTAssertEqual(1, update.tagGroupUpdates.count)
            XCTAssertEqual(1, update.attributeUpdates.count)
            XCTAssertEqual([activityUpdate], update.liveActivityUpdates)
            return AirshipHTTPResponse(result: nil, statusCode: 200, headers: [:])
        }

        var result = try? await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ChannelAudienceManager.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
        await fulfillment(of: [expectation])

        result = try? await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ChannelAudienceManager.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
    }

    func testGet() async throws {
        let expectedLists = ["cool", "story"]
        self.subscriptionListClient.getCallback = { identifier in
            XCTAssertEqual("some-channel", identifier)
            return AirshipHTTPResponse(
                result: expectedLists,
                statusCode: 200,
                headers: [:]
            )
        }
        let result = try await self.audienceManager.fetchSubscriptionLists()
        XCTAssertEqual(expectedLists, result)
    }

    func testGetCache() async throws {
        self.date.dateOverride = Date()

        var apiResult = ["cool", "story"]

        self.subscriptionListClient.getCallback = { identifier in
            XCTAssertEqual("some-channel", identifier)
            return AirshipHTTPResponse(
                result: apiResult,
                statusCode: 200,
                headers: [:]
            )
        }

        // Populate cache
        var result = try await self.audienceManager.fetchSubscriptionLists()
        XCTAssertEqual(["cool", "story"], result)

        apiResult = ["some-other-result"]

        // From cache
        result = try await self.audienceManager.fetchSubscriptionLists()
        XCTAssertEqual(["cool", "story"], result)
        self.date.offset += 599  // 1 second before cache should invalidate

        // From cache
        result = try await self.audienceManager.fetchSubscriptionLists()
        XCTAssertEqual(["cool", "story"], result)

        self.date.offset += 1

        // From api
        result = try await self.audienceManager.fetchSubscriptionLists()
        XCTAssertEqual(["some-other-result"], result)
    }

    func testNoPendingOperations() async throws {
        let result = try? await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ChannelAudienceManager.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
        XCTAssertEqual(0, self.workManager.workRequests.count)
    }

    func testEnableEnqueuesTask() throws {
        self.audienceManager.enabled = false
        XCTAssertEqual(0, self.workManager.workRequests.count)

        self.audienceManager.enabled = true
        XCTAssertEqual(1, self.workManager.workRequests.count)
    }

    func testSetChannelIDEnqueuesTask() throws {
        self.audienceManager.channelID = nil
        XCTAssertEqual(0, self.workManager.workRequests.count)

        self.audienceManager.channelID = "sweet"
        XCTAssertEqual(1, self.workManager.workRequests.count)
    }

    func testPrivacyManagerDisabledIgnoresUpdates() async throws {
        self.privacyManager.disableFeatures(.tagsAndAttributes)

        let editor = self.audienceManager.editSubscriptionLists()
        editor.subscribe("pizza")
        editor.unsubscribe("coffee")
        editor.apply()

        self.updateClient.updateCallback = { identifier, update in
            return AirshipHTTPResponse(result: nil, statusCode: 200, headers: [:])
        }

        self.privacyManager.enableFeatures(.tagsAndAttributes)
        _ = try? await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ChannelAudienceManager.updateTaskID
            )
        )
    }

    func testMigrateMutations() async throws {
        let testDate = UATestDate()
        testDate.dateOverride = Date()

        let attributePayload = [
            "action": "remove",
            "key": "some-attribute",
            "timestamp": AirshipDateFormatter.string(fromDate: testDate.now, format: .isoDelimitter)
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
            forKey: ChannelAudienceManager.legacyPendingAttributesKey
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
        dataStore.setObject(
            tagData,
            forKey: ChannelAudienceManager.legacyPendingTagGroupsKey
        )

        self.audienceManager.migrateMutations()

        let pending = await self.audienceOverridesProvider.pendingOverrides(channelID: "some-channel")
        XCTAssertEqual(
            [
                TagGroupUpdate(group: "some-group", tags: ["tag"], type: .add)
            ],
            pending?.tags
        )

        XCTAssertEqual(
            [
                AttributeUpdate.remove(
                    attribute: "some-attribute",
                    date: AirshipDateFormatter.date(fromISOString: attributePayload["timestamp"]!)!
                )
            ],
            pending?.attributes
        )
    }

    func testGetSubscriptionListOverrides() async throws {
        await self.audienceOverridesProvider.setStableContactIDProvider {
            "some contact ID"
        }

        await self.audienceOverridesProvider.contactUpdated(
            contactID: "some contact ID",
            tags: nil,
            attributes: nil,
            subscriptionLists: [
                ScopedSubscriptionListUpdate(listId: "bar", type: .subscribe, scope: .app, date: Date()),
                ScopedSubscriptionListUpdate(listId: "baz", type: .unsubscribe, scope: .app, date: Date())
            ], channels: []
        )


        self.subscriptionListClient.getCallback = { identifier in
            return AirshipHTTPResponse(
                result: ["cool", "baz"],
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.audienceManager.fetchSubscriptionLists()
        XCTAssertEqual(["cool", "bar"], result)
    }

    func testSubscriptionListEdits() throws {
        var edits = [SubscriptionListEdit]()

        let expectation = self.expectation(description: "Publisher")
        expectation.expectedFulfillmentCount = 3
        let cancellable = self.audienceManager.subscriptionListEdits.sink {
            edits.append($0)
            expectation.fulfill()
        }

        let editor = self.audienceManager.editSubscriptionLists()
        editor.unsubscribe("apple")
        editor.unsubscribe("pen")
        editor.subscribe("apple pen")
        editor.apply()

        self.waitForExpectations(timeout: 10.0)

        let expected: [SubscriptionListEdit] = [
            .unsubscribe("apple"),
            .unsubscribe("pen"),
            .subscribe("apple pen"),
        ]

        XCTAssertEqual(expected, edits)
        cancellable.cancel()
    }

    func testLiveActivityUpdates() async throws {
        let activityUpdate = LiveActivityUpdate(
            action: .set,
            source: .liveActivity(id: "foo", name: "bar", startTimeMS: 10),
            actionTimeMS: 10
        )

        self.audienceManager.addLiveActivityUpdate(activityUpdate)
        let expectation = XCTestExpectation(description: "callback called")
        self.updateClient.updateCallback = { identifier, update in
            expectation.fulfill()
            XCTAssertEqual("some-channel", identifier)
            XCTAssertEqual([activityUpdate], update.liveActivityUpdates)
            return AirshipHTTPResponse(result: nil, statusCode: 200, headers: [:])
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ChannelAudienceManager.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
        await fulfillment(of: [expectation])
    }

    func testLiveActivityUpdateAdjustTimestamps() async throws {
        let activityUpdates = [
            LiveActivityUpdate(
                action: .set,
                source: .liveActivity(id: "foo", name: "bar", startTimeMS: 10),
                actionTimeMS: 10
            ),
            LiveActivityUpdate(
                action: .remove,
                source: .liveActivity(id: "foo", name: "bar", startTimeMS: 10),
                actionTimeMS: 10
            ),
            LiveActivityUpdate(
                action: .set,
                source: .liveActivity(id: "some other foo", name: "bar", startTimeMS: 10),
                actionTimeMS: 10
            ),
            LiveActivityUpdate(
                action: .set,
                source: .liveActivity(id: "something else", name: "something else", startTimeMS: 10),
                actionTimeMS: 10
            ),
        ]

        let expected = [
            LiveActivityUpdate(
                action: .set,
                source: .liveActivity(id: "foo", name: "bar", startTimeMS: 10),
                actionTimeMS: 10
            ),
            LiveActivityUpdate(
                action: .remove,
                source: .liveActivity(id: "foo", name: "bar", startTimeMS: 10),
                actionTimeMS: 11
            ),
            LiveActivityUpdate(
                action: .set,
                source: .liveActivity(id: "some other foo", name: "bar", startTimeMS: 10),
                actionTimeMS: 12
            ),
            LiveActivityUpdate(
                action: .set,
                source: .liveActivity(id: "something else", name: "something else", startTimeMS: 10),
                actionTimeMS: 13
            ),
        ]

        activityUpdates.forEach { update in
            self.audienceManager.addLiveActivityUpdate(update)
        }

        let expectation = XCTestExpectation(description: "callback called")
        self.updateClient.updateCallback = { identifier, update in
            expectation.fulfill()
            XCTAssertEqual("some-channel", identifier)
            XCTAssertEqual(expected, update.liveActivityUpdates)
            return AirshipHTTPResponse(result: nil, statusCode: 200, headers: [:])
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ChannelAudienceManager.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
        await fulfillment(of: [expectation])
    }

    func testLiveActivityUpdatesStream() async throws {
        let updates = [
            LiveActivityUpdate(
                action: .set,
                source: .liveActivity(id: "foo", name: "bar", startTimeMS: 10),
                actionTimeMS: 10
            ),
            LiveActivityUpdate(
                action: .remove,
                source: .liveActivity(id: "foo", name: "bar", startTimeMS: 10),
                actionTimeMS: 11
            ),
            LiveActivityUpdate(
                action: .set,
                source: .liveActivity(id: "some other foo", name: "bar", startTimeMS: 10),
                actionTimeMS: 12
            ),
        ]

        updates.forEach { update in
            self.audienceManager.addLiveActivityUpdate(update)
        }

        let expectation = XCTestExpectation(description: "callback called")
        self.updateClient.updateCallback = { identifier, update in
            expectation.fulfill()
            XCTAssertEqual(updates, update.liveActivityUpdates)
            return AirshipHTTPResponse(result: nil, statusCode: 200, headers: [:])
        }

        let result = try? await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ChannelAudienceManager.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
        await fulfillment(of: [expectation])

        var iterator = self.audienceManager.liveActivityUpdates.makeAsyncIterator()
        let actualUpdates = await iterator.next()

        XCTAssertEqual(actualUpdates, updates)

    }

}
