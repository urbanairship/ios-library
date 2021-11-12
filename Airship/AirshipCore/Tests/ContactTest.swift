/* Copyright Airship and Contributors */

import XCTest


@testable
import AirshipCore

class TestDelegate : ContactConflictDelegate {
    var onConflictBlock : ((ContactData, String?) -> Void)?
    func onConflict(anonymousContactData: ContactData, namedUserID: String?) {
        onConflictBlock!(anonymousContactData, namedUserID)
    }
}

class ContactTest: XCTestCase {
    var contact: Contact!
    var taskManager: TestTaskManager!
    var channel: TestChannel!
    var apiClient: TestContactAPIClient!
    var notificationCenter: NotificationCenter!
    var date: UATestDate!
    var privacyManager: PrivacyManager!
    var dataStore: PreferenceDataStore!
        
    override func setUpWithError() throws {

        self.notificationCenter = NotificationCenter()
        self.channel = TestChannel()
        self.taskManager = TestTaskManager()
        self.apiClient = TestContactAPIClient()
        self.apiClient.defaultCallback = { method in
            XCTFail("Method \(method) called unexpectedly")
        }
    
        self.date = UATestDate()
        
        self.dataStore = PreferenceDataStore(appKey: UUID().uuidString)
        self.privacyManager = PrivacyManager(dataStore: self.dataStore, defaultEnabledFeatures: .all, notificationCenter: self.notificationCenter)
        
        
        let config = RuntimeConfig(config: Config(), dataStore: dataStore)
        
        self.contact = Contact(dataStore: self.dataStore,
                               config: config,
                               channel: self.channel,
                               privacyManager: self.privacyManager,
                               contactAPIClient: self.apiClient,
                               taskManager: self.taskManager,
                               notificationCenter: self.notificationCenter,
                               date: self.date)
        
        // Verify init enqueues an update task
        XCTAssertEqual(1, self.taskManager.enqueuedRequests.count)
        self.taskManager.enqueuedRequests.removeAll()
        
        self.channel.identifier = "channel id"
    }
    
    func testMigrateNamedUser() throws {
        let testDate = UATestDate()
        testDate.dateOverride = Date()
        
        let attributePayload = [
            "action": "remove",
            "key": "some-attribute",
            "timestamp": Utils.isoDateFormatterUTCWithDelimiter().string(from: testDate.now)
        ]
        
        let attributeMutation = AttributePendingMutations(mutationsPayload: [attributePayload])
        let attributeData = try! NSKeyedArchiver.archivedData(withRootObject:[attributeMutation], requiringSecureCoding:true)
        dataStore.setObject(attributeData, forKey: Contact.legacyPendingAttributesKey)
        
        let tagMutation = TagGroupsMutation(adds: ["some-group": Set(["tag"])], removes: nil, sets: nil)
        let tagData = try! NSKeyedArchiver.archivedData(withRootObject:[tagMutation], requiringSecureCoding:true)
        dataStore.setObject(tagData, forKey: Contact.legacyPendingTagGroupsKey)

            
        self.dataStore.setObject("named-user", forKey: Contact.legacyNamedUserKey)
        self.contact.migrateNamedUser()

        XCTAssertEqual("named-user", contact.namedUserID)
        
        let pendingTagUpdates = [TagGroupUpdate(group: "some-group", tags: ["tag"], type: .add)]
        XCTAssertEqual(pendingTagUpdates, self.contact.pendingTagGroupUpdates)

        let pendingAttributeUpdates = [AttributeUpdate.remove(attribute: "some-attribute")]
        XCTAssertEqual(pendingAttributeUpdates, self.contact.pendingAttributeUpdates)
    }
    
    /// Test skip calling identify on the legacy named user if we already have contact data
    func testSkipMigrateLegacyNamedUser() throws {
        notificationCenter.post(Notification(name: AppStateTracker.didBecomeActiveNotification))
    
        XCTAssertEqual(1, self.taskManager.enqueuedRequests.count)
        
        let expectation = XCTestExpectation(description: "callback called")
        self.apiClient.resolveCallback = { channelID, callback in
            XCTAssertEqual("channel id", channelID)
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: true), nil)
            expectation.fulfill()
        }
        
        let task = self.taskManager.launchSync(taskID: Contact.updateTaskID)
        XCTAssertTrue(task.completed)
        
        wait(for: [expectation], timeout: 10.0)
        
        self.dataStore.setObject("named-user", forKey: Contact.legacyNamedUserKey)
        self.contact.migrateNamedUser()
        
        XCTAssertNil(self.contact.namedUserID)
    }
    
    func testNoPendingOperations() throws {
        let task = self.taskManager.launchSync(taskID: Contact.updateTaskID)
        XCTAssertTrue(task.completed)
        XCTAssertEqual(0, self.taskManager.enqueuedRequests.count)
    }
    
    func testChannelCreatedEnqueuesUpdateTask() throws {
        notificationCenter.post(Notification(name: AppStateTracker.didBecomeActiveNotification))
    
        XCTAssertEqual(1, self.taskManager.enqueuedRequests.count)
        self.taskManager.enqueuedRequests.removeAll()
        
        let expectation = XCTestExpectation(description: "callback called")

        self.apiClient.resolveCallback = { identifier, callback in
            expectation.fulfill()
            XCTAssertEqual("channel id", identifier)
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: true), nil)
        }
        
        let task = self.taskManager.launchSync(taskID: Contact.updateTaskID)
        XCTAssertTrue(task.completed)
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testExtendRegistrationPaylaodNilContactID() throws {
        XCTAssertEqual(1, self.channel.extenders.count)
        
        let expectation = XCTestExpectation(description: "callback called")
        self.channel.extenders[0](ChannelRegistrationPayload()) { payload in
            XCTAssertNil(payload.channel.contactID)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testExtendRegistrationPaylaod() throws {
        notificationCenter.post(Notification(name: AppStateTracker.didBecomeActiveNotification))
    
        XCTAssertEqual(1, self.taskManager.enqueuedRequests.count)
        
        let expectation = XCTestExpectation(description: "callback called")
        self.apiClient.resolveCallback = { channelID, callback in
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: true), nil)
            expectation.fulfill()
        }
        
        let task = self.taskManager.launchSync(taskID: Contact.updateTaskID)
        XCTAssertTrue(task.completed)
        
        wait(for: [expectation], timeout: 10.0)
        
        XCTAssertEqual(1, self.channel.extenders.count)
        
        let extendedCallback = XCTestExpectation(description: "callback called")
        self.channel.extenders[0](ChannelRegistrationPayload()) { payload in
            XCTAssertEqual("some-contact-id", payload.channel.contactID)
            extendedCallback.fulfill()
        }
        
        wait(for: [extendedCallback], timeout: 10.0)
    }

    func testForegroundResolves() throws {
        notificationCenter.post(Notification(name: AppStateTracker.didBecomeActiveNotification))
    
        XCTAssertEqual(1, self.taskManager.enqueuedRequests.count)
        
        let expectation = XCTestExpectation(description: "callback called")
        self.apiClient.resolveCallback = { channelID, callback in
            XCTAssertEqual("channel id", channelID)
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: true), nil)
            expectation.fulfill()
        }
        
        let task = self.taskManager.launchSync(taskID: Contact.updateTaskID)
        XCTAssertTrue(task.completed)
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testForegroundSkipsResolvesLessThan24Hours() throws {
        self.date.dateOverride = Date()
        
        notificationCenter.post(Notification(name: AppStateTracker.didBecomeActiveNotification))
        XCTAssertEqual(1, self.taskManager.enqueuedRequests.count)
        let expectation = XCTestExpectation(description: "callback called")
        self.apiClient.resolveCallback = { channelID, callback in
            XCTAssertEqual("channel id", channelID)
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: true), nil)
            expectation.fulfill()
        }
        
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        wait(for: [expectation], timeout: 10.0)
        
        self.taskManager.enqueuedRequests.removeAll()
        self.apiClient.resetCallback = nil
        
        notificationCenter.post(Notification(name: AppStateTracker.didBecomeActiveNotification))
        XCTAssertEqual(0, self.taskManager.enqueuedRequests.count)
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
    }
    
    func testChannelCreatedResolves() throws {
        notificationCenter.post(Notification(name: Channel.channelCreatedEvent))
    
        XCTAssertEqual(1, self.taskManager.enqueuedRequests.count)
        
        let expectation = XCTestExpectation(description: "callback called")
        self.apiClient.resolveCallback = { channelID, callback in
            XCTAssertEqual("channel id", channelID)
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: true), nil)
            expectation.fulfill()
        }
        
        let task = self.taskManager.launchSync(taskID: Contact.updateTaskID)
        XCTAssertTrue(task.completed)
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testIdentify() throws {
        self.contact.identify("cool user 1")
        
        XCTAssertEqual(1, self.taskManager.enqueuedRequests.count)
        
        let expectation = XCTestExpectation(description: "callback called")
        self.apiClient.identifyCallback = { channelID, namedUserID, contactID, callback in
            XCTAssertEqual("channel id", channelID)
            XCTAssertEqual("cool user 1", namedUserID)
            XCTAssertNil(contactID)
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: false), nil)
            expectation.fulfill()
        }
        
        let task = self.taskManager.launchSync(taskID: Contact.updateTaskID)
        XCTAssertTrue(task.completed)
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testReset() throws {
        self.contact.reset()
        
        XCTAssertEqual(1, self.taskManager.enqueuedRequests.count)
        
        let expectation = XCTestExpectation(description: "callback called")
        self.apiClient.resetCallback = { channelID, callback in
            XCTAssertEqual("channel id", channelID)
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: true), nil)
            expectation.fulfill()
        }
        
        let task = self.taskManager.launchSync(taskID: Contact.updateTaskID)
        XCTAssertTrue(task.completed)
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testSkipSandwichedIdentifyCalls() throws {
        self.contact.identify("one")
        self.contact.identify("two")
        self.contact.identify("three")
        self.contact.identify("four")
        
        XCTAssertEqual(4, self.taskManager.enqueuedRequests.count)
        
        let firstCallback = XCTestExpectation(description: "callback called")
        self.apiClient.identifyCallback = { channelID, namedUserID, contactID, callback in
            XCTAssertEqual("channel id", channelID)
            XCTAssertEqual("one", namedUserID)
            XCTAssertNil(contactID)
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: false), nil)
            firstCallback.fulfill()
        }
        
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        wait(for: [firstCallback], timeout: 10.0)
        XCTAssertEqual(5, self.taskManager.enqueuedRequests.count)

        let secondCallback = XCTestExpectation(description: "callback called")
        self.apiClient.identifyCallback = { channelID, namedUserID, contactID, callback in
            XCTAssertEqual("channel id", channelID)
            XCTAssertEqual("four", namedUserID)
            XCTAssertNil(contactID)
            callback(ContactAPIResponse(status: 200, contactID: "some-other-contact-id", isAnonymous: false), nil)
            secondCallback.fulfill()
        }
        
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        wait(for: [secondCallback], timeout: 10.0)
        XCTAssertEqual(6, self.taskManager.enqueuedRequests.count)
    }
    
    func testCombineSequentialUpdates() throws {
        let tagEdits = self.contact.editTagGroups()
        tagEdits.add(["neat"], group: "cool")
        tagEdits.apply()
        XCTAssertEqual(1, self.taskManager.enqueuedRequests.count)
        
        let attributeEdits = self.contact.editAttributes()
        attributeEdits.set(int: 1, attribute: "one")
        attributeEdits.apply()
        XCTAssertEqual(2, self.taskManager.enqueuedRequests.count)
        
        // Should resolve first
        let resolve = XCTestExpectation(description: "resolve contact")
        self.apiClient.resolveCallback = { channelID, callback in
            XCTAssertEqual("channel id", channelID)
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: true), nil)
            resolve.fulfill()
        }

        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        wait(for: [resolve], timeout: 10.0)
    
        // Then update
        let update = XCTestExpectation(description: "callback called")
        self.apiClient.updateCallback = { contactID, tagUpdates, attributeUpdates, callback in
            XCTAssertEqual("some-contact-id", contactID)
            XCTAssertEqual(1, tagUpdates?.count ?? 0)
            XCTAssertEqual(1, attributeUpdates?.count ?? 0)
            callback(HTTPResponse(status: 200), nil)
            update.fulfill()
        }
        
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        wait(for: [update], timeout: 10.0)
        
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
    }
    
    func testSkipResolves() throws {
        self.contact.identify("one")
        notificationCenter.post(Notification(name: Channel.channelCreatedEvent))
        notificationCenter.post(Notification(name: Channel.channelCreatedEvent))
        notificationCenter.post(Notification(name: Channel.channelCreatedEvent))
        notificationCenter.post(Notification(name: Channel.channelCreatedEvent))
        notificationCenter.post(Notification(name: Channel.channelCreatedEvent))

        self.apiClient.resolveCallback = { channelID, callback in
            XCTFail()
        }
        
        let identifyCallback = XCTestExpectation(description: "callback called")
        self.apiClient.identifyCallback = { channelID, namedUserID, contactID, callback in
            XCTAssertEqual("channel id", channelID)
            XCTAssertEqual("one", namedUserID)
            XCTAssertNil(contactID)
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: false), nil)
            identifyCallback.fulfill()
        }
        
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        wait(for: [identifyCallback], timeout: 10.0)

        // queue should be empty
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
    }
    
    func testConflictOnIdentify() {
        self.apiClient.resolveCallback = { channelID, callback in
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: true), nil)
        }
        
        self.apiClient.updateCallback = { contactID, tagUpdates, attributeUpdates, callback in
            callback(HTTPResponse(status: 200), nil)
        }
        
        self.apiClient.identifyCallback = { channelID, namedUserID, contactID, callback in
            callback(ContactAPIResponse(status: 200, contactID: "some-other-contact-id", isAnonymous: false), nil)
        }
        
        let delegate = TestDelegate()
        let conflictCalled = XCTestExpectation(description: "conflict called")

        delegate.onConflictBlock = { data, namedUserID in
            XCTAssertEqual("some-user", namedUserID)
            XCTAssertEqual(["cool": ["neat"]]  as NSDictionary, data.tags  as NSDictionary)
            XCTAssertEqual(["one": 1] as NSDictionary, data.attributes as NSDictionary)
            conflictCalled.fulfill()
        }
        
        self.contact.conflictDelegate = delegate
        
        let tagEdits = self.contact.editTagGroups()
        tagEdits.add(["neat"], group: "cool")
        tagEdits.apply()
    
        let attributeEdits = self.contact.editAttributes()
        attributeEdits.set(int: 1, attribute: "one")
        attributeEdits.apply()
        
        contact.identify("some-user")
        
        // resolve
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        // tags
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        // attributes
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        // identify
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        
        wait(for: [conflictCalled], timeout: 10.0)
    }
    
    func testConflictOnResolve() {
        var first = true
        self.apiClient.resolveCallback = { channelID, callback in
            if (first) {
                first = false
                callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: true), nil)
            } else {
                callback(ContactAPIResponse(status: 200, contactID: "some-other-contact-id", isAnonymous: true), nil)
            }
        }
        
        self.apiClient.updateCallback = { contactID, tagUpdates, attributeUpdates, callback in
            callback(HTTPResponse(status: 200), nil)
        }
        
        let delegate = TestDelegate()
        let conflictCalled = XCTestExpectation(description: "conflict called")

        delegate.onConflictBlock = { data, namedUserID in
            XCTAssertNil(namedUserID)
            XCTAssertEqual(["cool": ["neat"]]  as NSDictionary, data.tags  as NSDictionary)
            XCTAssertEqual(["one": 1] as NSDictionary, data.attributes as NSDictionary)
            conflictCalled.fulfill()
        }
        
        self.contact.conflictDelegate = delegate
        
        let tagEdits = self.contact.editTagGroups()
        tagEdits.add(["neat"], group: "cool")
        tagEdits.apply()
    
        let attributeEdits = self.contact.editAttributes()
        attributeEdits.set(int: 1, attribute: "one")
        attributeEdits.apply()
        
        // resolve
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        // tags
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        // attributes
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)        
        // resolve with conflict
        notificationCenter.post(Notification(name: Channel.channelCreatedEvent))
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        
        wait(for: [conflictCalled], timeout: 10.0)
    }
    
    func testResolveSkippedContactsDisabled() {
        self.privacyManager.disableFeatures(.contacts)
        
        notificationCenter.post(Notification(name: Channel.channelCreatedEvent))
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
    }
    
    func testTagsAndAttributesSkippedContactsDisabled() {
        self.privacyManager.disableFeatures(.contacts)
        
        let tagEdits = self.contact.editTagGroups()
        tagEdits.add(["neat"], group: "cool")
        tagEdits.apply()
    
        let attributeEdits = self.contact.editAttributes()
        attributeEdits.set(int: 1, attribute: "one")
        attributeEdits.apply()
        
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)

        self.privacyManager.disableFeatures(.tagsAndAttributes)
        self.privacyManager.enableFeatures(.contacts)
        
        tagEdits.apply()
        attributeEdits.apply()
        
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
    }
    
    func testIdentifySkippedContactsDisabled() throws {
        self.privacyManager.disableFeatures(.contacts)
        
        self.contact.identify("cat")
        
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
    }
    
    func testResetOnDisbleContacts() throws {
        self.contact.identify("cat")
        self.apiClient.identifyCallback = { channelID, namedUserID, contactID, callback in
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: false), nil)
        }
        
        let expectation = XCTestExpectation(description: "callback called")
        self.apiClient.resetCallback = { channelID, callback in
            XCTAssertEqual("channel id", channelID)
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: true), nil)
            expectation.fulfill()
        }
        
        // identify
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        
        self.privacyManager.disableFeatures(.contacts)
        
        // reset
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testIdentifyFailed() throws {
        self.contact.identify("cool user 1")
        
        let expectation = XCTestExpectation(description: "callback called")
        expectation.expectedFulfillmentCount = 2
        self.apiClient.identifyCallback = { channelID, namedUserID, contactID, callback in
            callback(ContactAPIResponse(status: 500, contactID: nil, isAnonymous: nil), nil)
            expectation.fulfill()
        }
        
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).failed)
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).failed)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testResetFailed() throws {
        self.contact.reset()
        
        let expectation = XCTestExpectation(description: "callback called")
        expectation.expectedFulfillmentCount = 2
        self.apiClient.resetCallback = { channelID, callback in
            callback(ContactAPIResponse(status: 505, contactID: nil, isAnonymous: nil), nil)
            expectation.fulfill()
        }
        
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).failed)
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).failed)
            
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testUpdateFailed() throws {
        let attributeEdits = self.contact.editAttributes()
        attributeEdits.set(int: 1, attribute: "one")
        attributeEdits.apply()

        self.apiClient.resolveCallback = { channelID, callback in
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: true), nil)
        }

        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
    
        let expectation = XCTestExpectation(description: "callback called")
        expectation.expectedFulfillmentCount = 2
        self.apiClient.updateCallback = { contactID, tagUpdates, attributeUpdates, callback in
            callback(HTTPResponse(status: 500), nil)
            expectation.fulfill()
        }

        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).failed)
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).failed)
            
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testResolveFailed() throws {
        notificationCenter.post(Notification(name: AppStateTracker.didBecomeActiveNotification))

    
        let expectation = XCTestExpectation(description: "resolve contact")
        expectation.expectedFulfillmentCount = 2

        self.apiClient.resolveCallback = { channelID, callback in
            callback(ContactAPIResponse(status: 505, contactID: nil, isAnonymous: nil), nil)
            expectation.fulfill()
        }

        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).failed)
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).failed)
            
        wait(for: [expectation], timeout: 10.0)
    }
    
}
