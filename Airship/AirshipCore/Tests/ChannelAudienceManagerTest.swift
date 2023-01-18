/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

class ChannelAudienceManagerTest: XCTestCase {
    
    var taskManager: TestTaskManager!
    var notificationCenter: NotificationCenter!
    var date: UATestDate!
    var privacyManager: PrivacyManager!
    var dataStore: PreferenceDataStore!
    var subscriptionListClient: TestSubscriptionListAPIClient!
    var updateClient: TestChannelBulkUpdateAPIClient!

    var audienceManager: ChannelAudienceManager!

    override func setUpWithError() throws {
        self.notificationCenter = NotificationCenter()
        self.taskManager = TestTaskManager()
        self.subscriptionListClient = TestSubscriptionListAPIClient()
        self.subscriptionListClient.defaultCallback = { method in
            XCTFail("Method \(method) called unexpectedly")
        }
        
        self.updateClient = TestChannelBulkUpdateAPIClient()
        self.updateClient.defaultCallback = { method in
            XCTFail("Method \(method) called unexpectedly")
        }

    
        self.date = UATestDate()
        self.dataStore = PreferenceDataStore(appKey: UUID().uuidString)
        self.privacyManager = PrivacyManager(dataStore: self.dataStore, defaultEnabledFeatures: .all, notificationCenter: self.notificationCenter)
        
        self.audienceManager = ChannelAudienceManager(dataStore: self.dataStore,
                                                      taskManager: self.taskManager,
                                                      subscriptionListClient: self.subscriptionListClient,
                                                      updateClient: self.updateClient,
                                                      privacyManager: self.privacyManager,
                                                      notificationCenter: self.notificationCenter,
                                                      date: self.date);
        
        self.audienceManager.enabled = true
        self.audienceManager.channelID = "some-channel"
        
        self.taskManager.enqueuedRequests.removeAll()
    }

    func testUpdates() throws {
        let subscriptionListEditor = self.audienceManager.editSubscriptionLists()
        subscriptionListEditor.subscribe("pizza")
        subscriptionListEditor.unsubscribe("coffee")
        subscriptionListEditor.apply()
        
        subscriptionListEditor.subscribe("hotdogs")
        subscriptionListEditor.apply()
        
        let tagEditor = self.audienceManager.editTagGroups(allowDeviceGroup: true)
        tagEditor.add(["tag"], group: "some-group")
        tagEditor.apply()
        
        let attributeEditor = self.audienceManager.editAttributes()
        attributeEditor.set(string: "hello", attribute: "some-attribute")
        attributeEditor.apply()

        let activityUpdate = LiveActivityUpdate(
            action: .set,
            id: "foo",
            name: "bar",
            actionTimeMS: 10,
            startTimeMS: 10
        )

        self.audienceManager.addLiveActivityUpdate(activityUpdate)
        
        XCTAssertEqual(5, self.taskManager.enqueuedRequests.count)

        let expectation = XCTestExpectation(description: "callback called")

        self.updateClient.updateCallback = { identifier, update, callback in
            expectation.fulfill()
            XCTAssertEqual("some-channel", identifier)
            XCTAssertEqual(3, update.subscriptionListUpdates.count)
            XCTAssertEqual(1, update.tagGroupUpdates.count)
            XCTAssertEqual(1, update.attributeUpdates.count)
            XCTAssertEqual([activityUpdate], update.liveActivityUpdates)
            callback(HTTPResponse(status: 200), nil)
        }
        
        XCTAssertTrue(self.taskManager.launchSync(taskID: ChannelAudienceManager.updateTaskID).completed)

        wait(for: [expectation], timeout: 10.0)
        
        XCTAssertTrue(self.taskManager.launchSync(taskID: ChannelAudienceManager.updateTaskID).completed)
    }
    
    func testGet() throws {
        let expectedLists = ["cool", "story"]
        self.subscriptionListClient.getCallback = { identifier, callback in
            XCTAssertEqual("some-channel", identifier)
            callback(SubscriptionListFetchResponse(status: 200, listIDs: expectedLists), nil)
        }
        
        let expectation = XCTestExpectation(description: "callback called")
        self.audienceManager.fetchSubscriptionLists() { lists, error in
            XCTAssertEqual(expectedLists, lists)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testGetCache() throws {
        self.date.dateOverride = Date()
        
        var apiResult = ["cool", "story"]
        
        self.subscriptionListClient.getCallback = { identifier, callback in
            XCTAssertEqual("some-channel", identifier)
            callback(SubscriptionListFetchResponse(status: 200, listIDs: apiResult), nil)
        }
    
        // Populate cache
        var expectation = XCTestExpectation(description: "callback called")
        self.audienceManager.fetchSubscriptionLists() { lists, error in
            XCTAssertEqual(["cool", "story"], lists)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
        
        apiResult = ["some-other-result"]
        
        // From cache
        expectation = XCTestExpectation(description: "callback called")
        self.audienceManager.fetchSubscriptionLists() { lists, error in
            XCTAssertEqual(["cool", "story"], lists)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
        
        self.date.offset += 599 // 1 second before cache should invalidate
        
        // From cache
        expectation = XCTestExpectation(description: "callback called")
        self.audienceManager.fetchSubscriptionLists() { lists, error in
            XCTAssertEqual(["cool", "story"], lists)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
        
        self.date.offset += 1
        
        // From api
        expectation = XCTestExpectation(description: "callback called")
        self.audienceManager.fetchSubscriptionLists() { lists, error in
            XCTAssertEqual(["some-other-result"], lists)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testNoPendingOperations() throws {
        let task = self.taskManager.launchSync(taskID: ChannelAudienceManager.updateTaskID)
        XCTAssertTrue(task.completed)
        XCTAssertEqual(0, self.taskManager.enqueuedRequests.count)
    }
    
    func testEnableEnqueuesTask() throws {
        self.audienceManager.enabled = false
        XCTAssertEqual(0, self.taskManager.enqueuedRequests.count)

        self.audienceManager.enabled = true
        XCTAssertEqual(1, self.taskManager.enqueuedRequests.count)
    }
    
    func testSetChannelIDEnqueuesTask() throws {
        self.audienceManager.channelID = nil
        XCTAssertEqual(0, self.taskManager.enqueuedRequests.count)

        self.audienceManager.channelID = "sweet"
        XCTAssertEqual(1, self.taskManager.enqueuedRequests.count)
    }

    func testPrivacyManagerDisabledIgnoresUpdates() throws {
        self.privacyManager.disableFeatures(.tagsAndAttributes)
        
        let editor = self.audienceManager.editSubscriptionLists()
        editor.subscribe("pizza")
        editor.unsubscribe("coffee")
        editor.apply()
        
        self.privacyManager.enableFeatures(.tagsAndAttributes)
        let task = self.taskManager.launchSync(taskID: ChannelAudienceManager.updateTaskID)
        XCTAssertTrue(task.completed)
    }
    
    func testMigrateMutations() throws {
        let testDate = UATestDate()
        testDate.dateOverride = Date()

        let attributePayload = [
            "action": "remove",
            "key": "some-attribute",
            "timestamp": Utils.isoDateFormatterUTCWithDelimiter()
                .string(
                    from: testDate.now
                ),
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

        let pendingTagUpdates = [
            TagGroupUpdate(group: "some-group", tags: ["tag"], type: .add)
        ]
        XCTAssertEqual(
            pendingTagUpdates,
            self.audienceManager.pendingTagGroupUpdates
        )

        let pendingAttributeUpdates = [
            AttributeUpdate.remove(attribute: "some-attribute")
        ]
        XCTAssertEqual(
            pendingAttributeUpdates,
            self.audienceManager.pendingAttributeUpdates
        )
    }

    func testContactSubscriptionListUpdates() throws {
        let updates = [
            SubscriptionListUpdate(listId: "bar", type: .subscribe),
            SubscriptionListUpdate(listId: "baz", type: .unsubscribe)
        ]

        self.audienceManager.processContactSubscriptionUpdates(updates)

        self.subscriptionListClient.getCallback = { identifier, callback in
            callback(SubscriptionListFetchResponse(status: 200, listIDs: ["cool", "baz"]), nil)
        }

        let expectation = self.expectation(description: "callback called")
        self.audienceManager.fetchSubscriptionLists() { lists, error in
            XCTAssertEqual(["cool", "bar"], lists)
            expectation.fulfill()
        }

        self.waitForExpectations(timeout: 10.0)
    }

    func testLiveActivityUpdates() throws {
        let activityUpdate = LiveActivityUpdate(
            action: .set,
            id: "foo",
            name: "bar",
            actionTimeMS: 10,
            startTimeMS: 10
        )

        self.audienceManager.addLiveActivityUpdate(activityUpdate)
        let expectation = XCTestExpectation(description: "callback called")
        self.updateClient.updateCallback = { identifier, update, callback in
            expectation.fulfill()
            XCTAssertEqual("some-channel", identifier)
            XCTAssertEqual([activityUpdate], update.liveActivityUpdates)
            callback(HTTPResponse(status: 200), nil)
        }

        XCTAssertTrue(
            self.taskManager.launchSync(
                taskID: ChannelAudienceManager.updateTaskID
            ).completed
        )

        wait(for: [expectation], timeout: 10.0)
    }

    func testLiveActivityUpdateAdjustTimestamps() throws {
        let activityUpdates = [
            LiveActivityUpdate(
                action: .set,
                id: "foo",
                name: "bar",
                actionTimeMS: 10,
                startTimeMS: 10
            ),
            LiveActivityUpdate(
                action: .remove,
                id: "foo",
                name: "bar",
                actionTimeMS: 10,
                startTimeMS: 10
            ),
            LiveActivityUpdate(
                action: .set,
                id: "some other foo",
                name: "bar",
                actionTimeMS: 10,
                startTimeMS: 10
            ),
            LiveActivityUpdate(
                action: .set,
                id: "something else",
                name: "something else",
                actionTimeMS: 1,
                startTimeMS: 1
            )
        ]

        let expected =  [
            LiveActivityUpdate(
                action: .set,
                id: "foo",
                name: "bar",
                actionTimeMS: 10,
                startTimeMS: 10
            ),
            LiveActivityUpdate(
                action: .remove,
                id: "foo",
                name: "bar",
                actionTimeMS: 11,
                startTimeMS: 10
            ),
            LiveActivityUpdate(
                action: .set,
                id: "some other foo",
                name: "bar",
                actionTimeMS: 12,
                startTimeMS: 10
            ),
            LiveActivityUpdate(
                action: .set,
                id: "something else",
                name: "something else",
                actionTimeMS: 1,
                startTimeMS: 1
            )
        ]

        activityUpdates.forEach { update in
            self.audienceManager.addLiveActivityUpdate(update)
        }

        let expectation = XCTestExpectation(description: "callback called")
        self.updateClient.updateCallback = { identifier, update, callback in
            expectation.fulfill()
            XCTAssertEqual("some-channel", identifier)
            XCTAssertEqual(expected, update.liveActivityUpdates)
            callback(HTTPResponse(status: 200), nil)
        }

        XCTAssertTrue(
            self.taskManager.launchSync(
                taskID: ChannelAudienceManager.updateTaskID
            ).completed
        )

        wait(for: [expectation], timeout: 10.0)
    }
}
