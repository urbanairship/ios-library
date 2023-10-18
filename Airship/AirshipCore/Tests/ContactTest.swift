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
    var channel: ContactTestChannel!
    var apiClient: TestContactAPIClient!
    var notificationCenter: NotificationCenter!
    var date: UATestDate!
    var privacyManager: PrivacyManager!
    var dataStore: PreferenceDataStore!
        
    override func setUpWithError() throws {

        self.notificationCenter = NotificationCenter()
        self.channel = ContactTestChannel()
        self.taskManager = TestTaskManager()
        self.apiClient = TestContactAPIClient()
        self.apiClient.defaultCallback = { method in
            XCTFail("Method \(method) called unexpectedly")
        }
    
        self.date = UATestDate()
        
        self.dataStore = PreferenceDataStore(appKey: UUID().uuidString)
        self.privacyManager = PrivacyManager(dataStore: self.dataStore, defaultEnabledFeatures: .all, notificationCenter: self.notificationCenter)

        self.contact = createContact()
        self.channel.identifier = "channel id"
    }

    func createContact() -> Contact {
        let config = RuntimeConfig(config: Config(), dataStore: dataStore)

        return Contact(dataStore: self.dataStore,
                       config: config,
                       channel: self.channel,
                       privacyManager: self.privacyManager,
                       contactAPIClient: self.apiClient,
                       taskManager: self.taskManager,
                       notificationCenter: self.notificationCenter,
                       date: self.date)
    }

    func testRateLimits() throws {
        XCTAssertEqual(2, self.taskManager.rateLimits.count)

        let updateRule = self.taskManager.rateLimits[Contact.updateRateLimitID]!
        XCTAssertEqual(1, updateRule.rate)
        XCTAssertEqual(0.5, updateRule.timeInterval, accuracy: 0.01)

        let identityRule = self.taskManager.rateLimits[Contact.identityRateLimitID]!
        XCTAssertEqual(1, identityRule.rate)
        XCTAssertEqual(5.0, identityRule.timeInterval, accuracy: 0.01)
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
    
    func testMigrateEmptyTagsAndAttributes() throws {
        let testDate = UATestDate()
        testDate.dateOverride = Date()
        
        let attributes: [AttributePendingMutations] = []
        let attributeData = try! NSKeyedArchiver.archivedData(withRootObject:attributes, requiringSecureCoding:true)
        dataStore.setObject(attributeData, forKey: Contact.legacyPendingAttributesKey)
        
        let tags: [TagGroupsMutation] = []
        let tagData = try! NSKeyedArchiver.archivedData(withRootObject:tags, requiringSecureCoding:true)
        dataStore.setObject([tagData], forKey: Contact.legacyPendingTagGroupsKey)
            
        self.dataStore.setObject("named-user", forKey: Contact.legacyNamedUserKey)
        self.contact.migrateNamedUser()

        XCTAssertEqual("named-user", contact.namedUserID)

        XCTAssertEqual([], self.contact.pendingTagGroupUpdates)
        XCTAssertEqual([], self.contact.pendingTagGroupUpdates)
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
    
    func testRegisterEmail() throws {
        self.contact.registerEmail("ua@airship.com", options: EmailRegistrationOptions.options(transactionalOptedIn: Date(), properties: ["interests" : "newsletter"], doubleOptIn: true))
        
        // Should resolve first
        let resolve = XCTestExpectation(description: "resolve contact")
        self.apiClient.resolveCallback = { channelID, callback in
            XCTAssertEqual("channel id", channelID)
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: true), nil)
            resolve.fulfill()
        }

        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        wait(for: [resolve], timeout: 10.0)
        
        XCTAssertEqual(2, self.taskManager.enqueuedRequests.count)
        
        // Then register email
        let expectation = XCTestExpectation(description: "callback called")
        self.apiClient.registerEmailCallback = { identifier, address, options, callback in
            XCTAssertEqual("some-contact-id", identifier)
            XCTAssertEqual("ua@airship.com", address)
            XCTAssertNotNil(options)
            let channel = AssociatedChannel(channelType: .email, channelID: "some-channel-id")
            callback(ContactAssociatedChannelResponse(status: 200, channel: channel), nil)
            expectation.fulfill()
        }
        
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testRegisterEmailFailed() throws {
        self.contact.registerEmail("ua@airship.com", options: EmailRegistrationOptions.options(transactionalOptedIn: Date(), properties: ["interests" : "newsletter"], doubleOptIn: true))
        
        // Should resolve first
        let resolve = XCTestExpectation(description: "resolve contact")
        self.apiClient.resolveCallback = { channelID, callback in
            XCTAssertEqual("channel id", channelID)
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: true), nil)
            resolve.fulfill()
        }

        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        wait(for: [resolve], timeout: 10.0)
        
        XCTAssertEqual(2, self.taskManager.enqueuedRequests.count)
        
        // Then register email
        let expectation = XCTestExpectation(description: "callback called")
        self.apiClient.registerEmailCallback = { identifier, address, options, callback in
            callback(ContactAssociatedChannelResponse(status: 500), nil)
            expectation.fulfill()
        }
        
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).failed)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testRegisterSMS() throws {
        self.contact.registerSMS("15035556789", options: SMSRegistrationOptions.optIn(senderID: "28855"))
        
        // Should resolve first
        let resolve = XCTestExpectation(description: "resolve contact")
        self.apiClient.resolveCallback = { channelID, callback in
            XCTAssertEqual("channel id", channelID)
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: true), nil)
            resolve.fulfill()
        }

        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        wait(for: [resolve], timeout: 10.0)
        
        XCTAssertEqual(2, self.taskManager.enqueuedRequests.count)
        
        // Then register sms
        let expectation = XCTestExpectation(description: "callback called")
        self.apiClient.registerSMSCallback = { identifier, msisdn, options, callback in
            XCTAssertEqual("some-contact-id", identifier)
            XCTAssertEqual("15035556789", msisdn)
            XCTAssertNotNil(options)
            let channel = AssociatedChannel(channelType: .sms, channelID: "some-channel-id")
            callback(ContactAssociatedChannelResponse(status: 200, channel: channel), nil)
            expectation.fulfill()
        }
        
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testRegisterSMSFailed() throws {
        self.contact.registerSMS("15035556789", options: SMSRegistrationOptions.optIn(senderID: "28855"))
        
        // Should resolve first
        let resolve = XCTestExpectation(description: "resolve contact")
        self.apiClient.resolveCallback = { channelID, callback in
            XCTAssertEqual("channel id", channelID)
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: true), nil)
            resolve.fulfill()
        }

        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        wait(for: [resolve], timeout: 10.0)
        
        XCTAssertEqual(2, self.taskManager.enqueuedRequests.count)
        
        // Then register sms
        let expectation = XCTestExpectation(description: "callback called")
        self.apiClient.registerSMSCallback = { identifier, msisdn, options, callback in
            callback(ContactAssociatedChannelResponse(status: 500), nil)
            expectation.fulfill()
        }
        
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).failed)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testRegisterOpen() throws {
        self.contact.registerOpen("open_address", options: OpenRegistrationOptions.optIn(platformName: "my_platform", identifiers: ["model":"4"]))
        
        // Should resolve first
        let resolve = XCTestExpectation(description: "resolve contact")
        self.apiClient.resolveCallback = { channelID, callback in
            XCTAssertEqual("channel id", channelID)
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: true), nil)
            resolve.fulfill()
        }

        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        wait(for: [resolve], timeout: 10.0)
        
        XCTAssertEqual(2, self.taskManager.enqueuedRequests.count)
        
        // Then register email
        let expectation = XCTestExpectation(description: "callback called")
        self.apiClient.registerOpenCallback = { identifier, address, options, callback in
            XCTAssertEqual("some-contact-id", identifier)
            XCTAssertEqual("open_address", address)
            XCTAssertNotNil(options)
            let channel = AssociatedChannel(channelType: .email, channelID: "some-channel-id")
            callback(ContactAssociatedChannelResponse(status: 200, channel: channel), nil)
            expectation.fulfill()
        }
        
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testRegisterOpenFailed() throws {
        self.contact.registerOpen("open_address", options: OpenRegistrationOptions.optIn(platformName: "my_platform", identifiers: ["model":"4"]))
        
        // Should resolve first
        let resolve = XCTestExpectation(description: "resolve contact")
        self.apiClient.resolveCallback = { channelID, callback in
            XCTAssertEqual("channel id", channelID)
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: true), nil)
            resolve.fulfill()
        }

        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        wait(for: [resolve], timeout: 10.0)
        
        XCTAssertEqual(2, self.taskManager.enqueuedRequests.count)
        
        // Then register email
        let expectation = XCTestExpectation(description: "callback called")
        self.apiClient.registerOpenCallback = { identifier, address, options, callback in
            callback(ContactAssociatedChannelResponse(status: 500), nil)
            expectation.fulfill()
        }
        
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).failed)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testAssociateChannel() throws {
        self.contact.associateChannel("some-channel-id", type: .email)
        
        // Should resolve first
        let resolve = XCTestExpectation(description: "resolve contact")
        self.apiClient.resolveCallback = { channelID, callback in
            XCTAssertEqual("channel id", channelID)
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: true), nil)
            resolve.fulfill()
        }

        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        wait(for: [resolve], timeout: 10.0)
        
        XCTAssertEqual(2, self.taskManager.enqueuedRequests.count)
        
        // Then associate
        let expectation = XCTestExpectation(description: "callback called")
        self.apiClient.associateChannelCallback = { identifier, channelID, channelType, callback in
            XCTAssertEqual("some-contact-id", identifier)
            XCTAssertEqual("some-channel-id", channelID)
            XCTAssertEqual(.email, channelType)
            let channel = AssociatedChannel(channelType: .email, channelID: "some-channel-id")
            callback(ContactAssociatedChannelResponse(status: 200, channel: channel), nil)
            expectation.fulfill()
        }
        
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testAssociateChannelFailed() throws {
        self.contact.associateChannel("some-channel-id", type: .email)
        
        // Should resolve first
        let resolve = XCTestExpectation(description: "resolve contact")
        self.apiClient.resolveCallback = { channelID, callback in
            XCTAssertEqual("channel id", channelID)
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: true), nil)
            resolve.fulfill()
        }

        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        wait(for: [resolve], timeout: 10.0)
        
        XCTAssertEqual(2, self.taskManager.enqueuedRequests.count)
        
        // Then associate
        let expectation = XCTestExpectation(description: "callback called")
        self.apiClient.associateChannelCallback = { identifier, channelID, channelType, callback in
            callback(ContactAssociatedChannelResponse(status: 500), nil)
            expectation.fulfill()
        }

        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).failed)
        wait(for: [expectation], timeout: 10.0)
    }

    func testResetsNotSkippedDuringIdentify() throws {
        self.contact.identify("one")
        self.contact.reset()
        self.contact.reset()
        self.contact.identify("one")
        self.contact.reset()

        let identify = XCTestExpectation(description: "identify")
        identify.expectedFulfillmentCount = 2
        identify.assertForOverFulfill = true
        self.apiClient.identifyCallback = { channelID, namedUserID, contactID, callback in
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: false), nil)
            identify.fulfill()
        }

        let reset = XCTestExpectation(description: "reset")
        reset.expectedFulfillmentCount = 2
        reset.assertForOverFulfill = true
        self.apiClient.resetCallback = { channelID, callback in
            callback(ContactAPIResponse(status: 200, contactID: "some-other-id", isAnonymous: true), nil)
            reset.fulfill()
        }

        // identify
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        // reset
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        // identify
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        // reset
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        // no-op
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        wait(for: [reset, identify], timeout: 10.0)
    }

    func testResetsNotSkippDuringUpdate() throws {
        self.contact.editTagGroups { editor in
            editor.add(["neat"], group: "cool")
        }

        self.contact.reset()
        self.contact.reset()

        self.contact.editTagGroups { editor in
            editor.add(["neat"], group: "cool")
        }

        self.contact.reset()

        // Should resolve first
        let resolve = XCTestExpectation(description: "resolve")
        self.apiClient.resolveCallback = { channelID, callback in
            XCTAssertEqual("channel id", channelID)
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: true), nil)
            resolve.fulfill()
        }

        let update = XCTestExpectation(description: "update")
        update.expectedFulfillmentCount = 2
        update.assertForOverFulfill = true
        self.apiClient.updateCallback = { contactID, tagUpdates, attributeUpdates, subscriptionListUpdates, callback in
            callback(HTTPResponse(status: 200), nil)
            update.fulfill()
        }

        let reset = XCTestExpectation(description: "reset")
        reset.expectedFulfillmentCount = 2
        reset.assertForOverFulfill = true
        self.apiClient.resetCallback = { channelID, callback in
            callback(ContactAPIResponse(status: 200, contactID: "some-other-id", isAnonymous: true), nil)
            reset.fulfill()
        }

        // resolve
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        // update
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        // reset
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        // update
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        // reset
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        // no-op
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)

        wait(for: [resolve, reset, update], timeout: 10.0)
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
        XCTAssertEqual(5, self.taskManager.enqueuedRequests.count)
    }
    
    func testCombineSequentialUpdates() throws {
        self.contact.editTagGroups { editor in
            editor.remove(["neat"], group: "cool")
        }


        self.contact.editTagGroups { editor in
            editor.add(["neat"], group: "cool")
        }

        XCTAssertEqual(2, self.taskManager.enqueuedRequests.count)

        self.contact.editAttributes { editor in
            editor.remove("one")
        }
        
        self.contact.editAttributes { editor in
            editor.set(int: 1, attribute: "one")
        }

        XCTAssertEqual(4, self.taskManager.enqueuedRequests.count)

        self.contact.editSubscriptionLists { editor in
            editor.unsubscribe("some list", scope: .app)
        }

        self.contact.editSubscriptionLists { editor in
            editor.subscribe("some list", scope: .app)
        }

        XCTAssertEqual(6, self.taskManager.enqueuedRequests.count)
        
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
        self.apiClient.updateCallback = { contactID, tagUpdates, attributeUpdates, subscriptionListUpdates, callback in
            XCTAssertEqual("some-contact-id", contactID)
            XCTAssertEqual(2, tagUpdates?.count ?? 0)
            XCTAssertEqual(TagGroupUpdateType.remove, tagUpdates?[0].type)
            XCTAssertEqual(TagGroupUpdateType.add, tagUpdates?[1].type)

            XCTAssertEqual(2, attributeUpdates?.count ?? 0)
            XCTAssertEqual(AttributeUpdateType.remove, attributeUpdates?[0].type)
            XCTAssertEqual(AttributeUpdateType.set, attributeUpdates?[1].type)

            XCTAssertEqual(2, subscriptionListUpdates?.count ?? 0)
            XCTAssertEqual(SubscriptionListUpdateType.unsubscribe, subscriptionListUpdates?[0].type)
            XCTAssertEqual(SubscriptionListUpdateType.subscribe, subscriptionListUpdates?[1].type)

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
        
        self.apiClient.updateCallback = { contactID, tagUpdates, attributeUpdates, subscriptionListsUpdates, callback in
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
            XCTAssertEqual(["foo": ChannelScopes([.app])], data.subscriptionLists)

            conflictCalled.fulfill()
        }
        
        self.contact.conflictDelegate = delegate
        
        let tagEdits = self.contact.editTagGroups()
        tagEdits.add(["neat"], group: "cool")
        tagEdits.apply()
    
        let attributeEdits = self.contact.editAttributes()
        attributeEdits.set(int: 1, attribute: "one")
        attributeEdits.apply()
        
        self.contact.editSubscriptionLists { editor in
            editor.subscribe("foo", scope: .app)
        }
        
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
        
        self.apiClient.updateCallback = { contactID, tagUpdates, attributeUpdates, subscriptionListsUpdates, callback in
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
        self.apiClient.updateCallback = { contactID, tagUpdates, attributeUpdates, subscriptionListsUpdates, callback in
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
    
    func testFetchSubscriptionLists() throws {
        // Resolve the contact ID
        notificationCenter.post(Notification(name: AppStateTracker.didBecomeActiveNotification))
        XCTAssertEqual(1, self.taskManager.enqueuedRequests.count)
        self.apiClient.resolveCallback = { channelID, callback in
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: true), nil)
        }
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)

        let apiResult: [String: [ChannelScope]] = ["neat": [.web]]
        let expected = AudienceUtils.wrap(apiResult)
        self.apiClient.fetchSubscriptionListsCallback = { identifier, callback in
            XCTAssertEqual("some-contact-id", identifier)
            callback(ContactSubscriptionListFetchResponse(200, apiResult), nil)
        }

        let expectation = XCTestExpectation(description: "callback called")
        self.contact.fetchSubscriptionLists { result, error in
            XCTAssertEqual(expected, result)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }
    
    func testFetchSubscriptionListsPendingReset() throws {
        // Resolve the contact ID
        notificationCenter.post(Notification(name: AppStateTracker.didBecomeActiveNotification))
        XCTAssertEqual(1, self.taskManager.enqueuedRequests.count)
        self.apiClient.resolveCallback = { channelID, callback in
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: true), nil)
        }
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)

        // Apply an update to current contact, to avoid skipping reset
        self.contact.editSubscriptionLists() { editor in
            editor.subscribe("neat", scope: .email)
        }
        self.contact.reset()
        
        let expectation = XCTestExpectation(description: "callback called")
        self.contact.fetchSubscriptionLists { result, error in
            XCTAssertNil(result)
            XCTAssertNotNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)
    }
    
    func testFetchSubscriptionListsPendingIdentify() throws {
        // Resolve the contact ID
        notificationCenter.post(Notification(name: AppStateTracker.didBecomeActiveNotification))
        XCTAssertEqual(1, self.taskManager.enqueuedRequests.count)
        self.apiClient.resolveCallback = { channelID, callback in
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: true), nil)
        }
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)

        // Reset the contact
        self.contact.identify("some user")
        
        let expectation = XCTestExpectation(description: "callback called")
        self.contact.fetchSubscriptionLists { result, error in
            XCTAssertNil(result)
            XCTAssertNotNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }
    
    func testFetchSubscriptionListsNoContact() throws {
        let expectation = XCTestExpectation(description: "callback called")
        self.contact.fetchSubscriptionLists { result, error in
            XCTAssertNil(result)
            XCTAssertNotNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }
    
    func testFetchSubscriptionListsCached() throws {
        self.date.dateOverride = Date()

        // Resolve the contact ID
        notificationCenter.post(Notification(name: AppStateTracker.didBecomeActiveNotification))
        XCTAssertEqual(1, self.taskManager.enqueuedRequests.count)
        self.apiClient.resolveCallback = { channelID, callback in
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: true), nil)
        }
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        
        
        var apiResult: [String: [ChannelScope]] = ["neat": [.web]]
        var expected = apiResult
        self.apiClient.fetchSubscriptionListsCallback = { identifier, callback in
            XCTAssertEqual("some-contact-id", identifier)
            callback(ContactSubscriptionListFetchResponse(200, apiResult), nil)
        }
        
        // Populate cache
        var expectation = XCTestExpectation(description: "callback called")
        self.contact.fetchSubscriptionLists() { result, error in
            XCTAssertEqual(AudienceUtils.wrap(expected), result)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)

        
        apiResult = ["something else": [.web]]

        // From cache
        expectation = XCTestExpectation(description: "callback called")
        self.contact.fetchSubscriptionLists { result, error in
            XCTAssertEqual(AudienceUtils.wrap(expected), result)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)

        self.date.offset += 599 // 1 second before cache should invalidate

        // From cache
        expectation = XCTestExpectation(description: "callback called")
        self.contact.fetchSubscriptionLists { result, error in
            XCTAssertEqual(AudienceUtils.wrap(expected), result)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)

        self.date.offset += 1

        // From api
        expected = apiResult
        expectation = XCTestExpectation(description: "callback called")
        self.contact.fetchSubscriptionLists { result, error in
            XCTAssertEqual(AudienceUtils.wrap(expected), result)
            expectation.fulfill()        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testFetchSubscriptionListsCachedDifferentContactID() throws {
        self.date.dateOverride = Date()

        // Resolve the contact ID
        notificationCenter.post(Notification(name: AppStateTracker.didBecomeActiveNotification))
        XCTAssertEqual(1, self.taskManager.enqueuedRequests.count)
        self.apiClient.resolveCallback = { channelID, callback in
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: true), nil)
        }
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        
        var apiResult: [String: [ChannelScope]] = ["neat": [ChannelScope.web]]
        var expected = apiResult
        self.apiClient.fetchSubscriptionListsCallback = { identifier, callback in
            callback(ContactSubscriptionListFetchResponse(200, apiResult), nil)
        }
        
        // Populate cache
        var expectation = XCTestExpectation(description: "callback called")
        self.contact.fetchSubscriptionLists() { result, error in
            XCTAssertEqual(AudienceUtils.wrap(expected), result)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)

        apiResult = ["something else": [.web]]

        // From cache
        expectation = XCTestExpectation(description: "callback called")
        self.contact.fetchSubscriptionLists { result, error in
            XCTAssertEqual(AudienceUtils.wrap(expected), result)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)

        // Resolve a new contact ID
        contact.identify("some user")
        self.apiClient.identifyCallback = { channelID, namedUserID, contactID, callback in
            callback(ContactAPIResponse(status: 200, contactID: "some-other-contact-id", isAnonymous: false), nil)
            expectation.fulfill()
        }
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)

        // From api
        expected = apiResult
        expectation = XCTestExpectation(description: "callback called")
        self.contact.fetchSubscriptionLists { result, error in
            XCTAssertEqual(AudienceUtils.wrap(expected), result)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testFetchSubscriptionListsPendingApplied() throws {
        // Resolve the contact ID
        notificationCenter.post(Notification(name: AppStateTracker.didBecomeActiveNotification))
        XCTAssertEqual(1, self.taskManager.enqueuedRequests.count)
        self.apiClient.resolveCallback = { channelID, callback in
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: true), nil)
        }
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)

        let apiResult: [String: [ChannelScope]] = ["foo": [.web, .sms]]
        self.apiClient.fetchSubscriptionListsCallback = { identifier, callback in
            XCTAssertEqual("some-contact-id", identifier)
            callback(ContactSubscriptionListFetchResponse(200, apiResult), nil)
        }
        
        self.contact.editSubscriptionLists { editor in
            editor.subscribe("bar", scope: .app)
            editor.unsubscribe("foo", scope: .sms)
        }

        let expected: [String: [ChannelScope]] = ["foo": [.web], "bar": [.app]]
        let expectation = XCTestExpectation(description: "callback called")
        self.contact.fetchSubscriptionLists { result, error in
            XCTAssertEqual(AudienceUtils.wrap(expected), result)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }
    
    func testFetchSubscriptionListsLocalHistoryApplied() throws {
        // Resolve the contact ID
        notificationCenter.post(Notification(name: AppStateTracker.didBecomeActiveNotification))
        XCTAssertEqual(1, self.taskManager.enqueuedRequests.count)
        self.apiClient.resolveCallback = { channelID, callback in
            callback(ContactAPIResponse(status: 200, contactID: "some-contact-id", isAnonymous: true), nil)
        }
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)

        self.contact.editSubscriptionLists { editor in
            editor.subscribe("bar", scope: .app)
        }

        // Apply update
        let update = XCTestExpectation(description: "update")
        self.apiClient.updateCallback = { contactID, tagUpdates, attributeUpdates, subscriptionListUpdates, callback in
            callback(HTTPResponse(status: 200), nil)
            update.fulfill()
        }
        XCTAssertTrue(self.taskManager.launchSync(taskID: Contact.updateTaskID).completed)
        wait(for: [update], timeout: 10.0)

        XCTAssertTrue(self.contact.pendingSubscriptionListUpdates.isEmpty)


        let apiResult: [String: [ChannelScope]] = ["foo": [.web]]
        self.apiClient.fetchSubscriptionListsCallback = { identifier, callback in
            XCTAssertEqual("some-contact-id", identifier)
            callback(ContactSubscriptionListFetchResponse(200, apiResult), nil)
        }

        let expected: [String: [ChannelScope]] = ["foo": [.web], "bar": [.app]]
        let expectation = XCTestExpectation(description: "callback called")
        self.contact.fetchSubscriptionLists { result, error in
            XCTAssertEqual(AudienceUtils.wrap(expected), result)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func testForwardAppSubscriptionListUpdates() throws {
        self.contact.editSubscriptionLists { editor in
            editor.subscribe("foo", scope: .web)
            editor.subscribe("bar", scope: .app)
            editor.unsubscribe("baz", scope: .app)
        }

        let expectedUpdates = [
            SubscriptionListUpdate(listId: "bar", type: .subscribe),
            SubscriptionListUpdate(listId: "baz", type: .unsubscribe)
        ]

        XCTAssertEqual(expectedUpdates, self.channel.contactUpdates)
    }

    func testForwardPendingAppSubscriptionListUpdatesOnInit() throws {
        self.contact.editSubscriptionLists { editor in
            editor.subscribe("foo", scope: .web)
            editor.subscribe("bar", scope: .app)
            editor.unsubscribe("baz", scope: .app)
        }

        self.channel.contactUpdates.removeAll()
        self.contact = createContact()

        let expectedUpdates = [
            SubscriptionListUpdate(listId: "bar", type: .subscribe),
            SubscriptionListUpdate(listId: "baz", type: .unsubscribe)
        ]

        XCTAssertEqual(expectedUpdates, self.channel.contactUpdates)
    }
}


class ContactTestChannel : NSObject, InternalChannelProtocol, Component {
    public var isComponentEnabled: Bool = true

    public var extenders: [((ChannelRegistrationPayload, @escaping (ChannelRegistrationPayload) -> Void) -> Void)] = []

    @objc
    public var identifier: String? = nil

    var contactUpdates: [SubscriptionListUpdate] = []

    @objc
    public var updateRegistrationCalled : Bool = false

    @objc
    public var isChannelCreationEnabled: Bool = false

    public var pendingAttributeUpdates: [AttributeUpdate] = []

    public var pendingTagGroupUpdates: [TagGroupUpdate] = []

    public var tags: [String] = []

    public var isChannelTagRegistrationEnabled: Bool = false

    @objc
    public var tagGroupEditor : TagGroupsEditor?

    @objc
    public var attributeEditor : AttributesEditor?

    @objc
    public var subscriptionListEditor : SubscriptionListEditor?


    public func updateRegistration(forcefully: Bool) {
        self.updateRegistrationCalled = true
    }

    public func editTags() -> TagEditor {
        return TagEditor { applicator in
            self.tags = applicator(self.tags)
        }
    }

    public func editTags(_ editorBlock: (TagEditor) -> Void) {
        let editor = editTags()
        editorBlock(editor)
        editor.apply()
    }

    public func editTagGroups() -> TagGroupsEditor {
        return self.tagGroupEditor!
    }

    public func editTagGroups(_ editorBlock: (TagGroupsEditor) -> Void) {
        let editor = editTagGroups()
        editorBlock(editor)
        editor.apply()
    }

    public func editSubscriptionLists() -> SubscriptionListEditor {
        return self.subscriptionListEditor!
    }

    public func editSubscriptionLists(_ editorBlock: (SubscriptionListEditor) -> Void) {
        let editor = editSubscriptionLists()
        editorBlock(editor)
        editor.apply()
    }

    public func fetchSubscriptionLists(completionHandler: @escaping ([String]?, Error?) -> Void) -> Disposable {
        fatalError("Not implemented")
    }

    public func editAttributes() -> AttributesEditor {
        return self.attributeEditor!
    }

    public func editAttributes(_ editorBlock: (AttributesEditor) -> Void) {
        let editor = editAttributes()
        editorBlock(editor)
        editor.apply()
    }

    public func enableChannelCreation() {
        self.isChannelCreationEnabled = true
    }

    public func updateRegistration() {
        self.updateRegistrationCalled = true
    }

    public func addRegistrationExtender(_ extender: @escaping  (ChannelRegistrationPayload, (@escaping (ChannelRegistrationPayload) -> Void)) -> Void) {
        self.extenders.append(extender)
    }

    public override var description: String {
        return "TestChannel"
    }

    @objc
    public func extendPayload(_ payload: ChannelRegistrationPayload, completionHandler: @escaping (ChannelRegistrationPayload) -> Void) {
        Channel.extendPayload(payload,
                              extenders: self.extenders,
                              completionHandler: completionHandler)
    }

    public func processContactSubscriptionUpdates(_ updates: [SubscriptionListUpdate]) {
        self.contactUpdates.append(contentsOf: updates)
    }
}

