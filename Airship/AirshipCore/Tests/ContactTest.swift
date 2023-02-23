/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

class TestDelegate: ContactConflictDelegate {
    var onConflictBlock: ((ContactData, String?) -> Void)?
    func onConflict(anonymousContactData: ContactData, namedUserID: String?) {
        onConflictBlock!(anonymousContactData, namedUserID)
    }
}

class ContactTest: XCTestCase {
    var contact: AirshipContact!
    var workManager: TestWorkManager!
    var channel: TestChannel!
    var apiClient: TestContactAPIClient!
    var notificationCenter: NotificationCenter!
    var date: UATestDate!
    var privacyManager: AirshipPrivacyManager!
    var dataStore: PreferenceDataStore!

    override func setUpWithError() throws {

        self.notificationCenter = NotificationCenter()
        self.channel = TestChannel()
        self.workManager = TestWorkManager()
        self.apiClient = TestContactAPIClient()

        self.date = UATestDate()

        self.dataStore = PreferenceDataStore(appKey: UUID().uuidString)
        self.privacyManager = AirshipPrivacyManager(
            dataStore: self.dataStore,
            defaultEnabledFeatures: .all,
            notificationCenter: self.notificationCenter
        )

        self.contact = createContact()
        self.channel.identifier = "channel id"
    }

    func createContact() -> AirshipContact {
        let config = RuntimeConfig(config: AirshipConfig(), dataStore: dataStore)

        return AirshipContact(
            dataStore: self.dataStore,
            config: config,
            channel: self.channel,
            privacyManager: self.privacyManager,
            contactAPIClient: self.apiClient,
            workManager: self.workManager,
            notificationCenter: self.notificationCenter,
            date: self.date
        )
    }

    func testRateLimits() async throws {
        try await self.workManager.setRateLimit(AirshipContact.updateRateLimitID, rate: 1, timeInterval: 0.5)
        try await self.workManager.setRateLimit(AirshipContact.identityRateLimitID, rate: 1, timeInterval: 5.0)
        
        let limiter = self.workManager.rateLimitor
    
        let rules = await limiter.rules
     
        XCTAssertEqual(2, rules.count)
        
        var updateRule = rules[AirshipContact.updateRateLimitID]!
        XCTAssertEqual(1, updateRule.rate)
        XCTAssertEqual(0.5, updateRule.timeInterval, accuracy: 0.01)
        
        updateRule = rules[AirshipContact.updateRateLimitID]!
        XCTAssertEqual(1, updateRule.rate)
        XCTAssertEqual(0.5, updateRule.timeInterval, accuracy: 0.01)
        
        let identityRule = rules[
            AirshipContact.identityRateLimitID
        ]!
        XCTAssertEqual(1, identityRule.rate)
        XCTAssertEqual(5.0, identityRule.timeInterval, accuracy: 0.01)
    }

    func testMigrateNamedUser() throws {
        let testDate = UATestDate()
        testDate.dateOverride = Date()

        let attributePayload = [
            "action": "remove",
            "key": "some-attribute",
            "timestamp": AirshipUtils.isoDateFormatterUTCWithDelimiter()
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
        self.contact.migrateNamedUser()

        XCTAssertEqual("named-user", contact.namedUserID)

        let pendingTagUpdates = [
            TagGroupUpdate(group: "some-group", tags: ["tag"], type: .add)
        ]
        XCTAssertEqual(pendingTagUpdates, self.contact.pendingTagGroupUpdates)

        let pendingAttributeUpdates = [
            AttributeUpdate.remove(attribute: "some-attribute")
        ]
        XCTAssertEqual(
            pendingAttributeUpdates,
            self.contact.pendingAttributeUpdates
        )
    }

    func testMigrateEmptyTagsAndAttributes() throws {
        let testDate = UATestDate()
        testDate.dateOverride = Date()

        let attributes: [AttributePendingMutations] = []
        let attributeData = try! NSKeyedArchiver.archivedData(
            withRootObject: attributes,
            requiringSecureCoding: true
        )
        dataStore.setObject(
            attributeData,
            forKey: AirshipContact.legacyPendingAttributesKey
        )

        let tags: [TagGroupsMutation] = []
        let tagData = try! NSKeyedArchiver.archivedData(
            withRootObject: tags,
            requiringSecureCoding: true
        )
        dataStore.setObject(
            [tagData],
            forKey: AirshipContact.legacyPendingTagGroupsKey
        )

        self.dataStore.setObject(
            "named-user",
            forKey: AirshipContact.legacyNamedUserKey
        )
        self.contact.migrateNamedUser()

        XCTAssertEqual("named-user", contact.namedUserID)

        XCTAssertEqual([], self.contact.pendingTagGroupUpdates)
        XCTAssertEqual([], self.contact.pendingTagGroupUpdates)
    }

    /// Test skip calling identify on the legacy named user if we already have contact data
    func testSkipMigrateLegacyNamedUser() async throws {
        notificationCenter.post(
            Notification(name: AppStateTracker.didBecomeActiveNotification)
        )

        XCTAssertEqual(1, self.workManager.workRequests.count)

        let expectation = XCTestExpectation(description: "callback called")
        self.apiClient.resolveCallback = { identifier in
            XCTAssertEqual("channel id", identifier)
            expectation.fulfill()
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: true
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        let request = self.workManager.workRequests[0]
        XCTAssertEqual(request.workID, AirshipContact.updateTaskID)
        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        wait(for: [expectation], timeout: 10.0)

        self.dataStore.setObject(
            "named-user",
            forKey: AirshipContact.legacyNamedUserKey
        )
        self.contact.migrateNamedUser()

        XCTAssertNil(self.contact.namedUserID)
    }

    func testNoPendingOperations() async throws {
        _ = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
                                    
        XCTAssertEqual(0, self.workManager.workRequests.count)
    }

    func testChannelCreatedEnqueuesUpdateTask() async throws {
        notificationCenter.post(
            Notification(name: AppStateTracker.didBecomeActiveNotification)
        )

        XCTAssertEqual(1, self.workManager.workRequests.count)
        self.workManager.workRequests.removeAll()

        let expectation = XCTestExpectation(description: "callback called")

        self.apiClient.resolveCallback = { identifier in
            XCTAssertEqual("channel id", identifier)
            expectation.fulfill()
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: true
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        wait(for: [expectation], timeout: 10.0)
    }

    func testExtendRegistrationPaylaodNilContactID() async throws {
        XCTAssertEqual(1, self.channel.extenders.count)

        let payload = await self.channel.channelPayload
        XCTAssertNil(payload.channel.contactID)
    }

    func testExtendRegistrationPaylaod() async throws {
        notificationCenter.post(
            Notification(name: AppStateTracker.didBecomeActiveNotification)
        )

        XCTAssertEqual(1, self.workManager.workRequests.count)

        let expectation = XCTestExpectation(description: "callback called")
        self.apiClient.resolveCallback = { identifier in
            XCTAssertEqual("channel id", identifier)
            expectation.fulfill()
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: true
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)


        wait(for: [expectation], timeout: 10.0)

        XCTAssertEqual(1, self.channel.extenders.count)

        let payload = await self.channel.channelPayload
        XCTAssertEqual("some-contact-id", payload.channel.contactID)
    }

    func testForegroundResolves() async throws {
        notificationCenter.post(
            Notification(name: AppStateTracker.didBecomeActiveNotification)
        )

        XCTAssertEqual(1, self.workManager.workRequests.count)

        let expectation = XCTestExpectation(description: "callback called")
        self.apiClient.resolveCallback = { identifier in
            XCTAssertEqual("channel id", identifier)
            expectation.fulfill()
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: true
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        wait(for: [expectation], timeout: 10.0)
    }

    func testForegroundSkipsResolvesLessThan24Hours() async throws {
        self.date.dateOverride = Date()

        notificationCenter.post(
            Notification(name: AppStateTracker.didBecomeActiveNotification)
        )
        XCTAssertEqual(1, self.workManager.workRequests.count)

        let expectation = XCTestExpectation(description: "callback called")
        self.apiClient.resolveCallback = { identifier in
            XCTAssertEqual("channel id", identifier)
            expectation.fulfill()
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: true
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        var result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        wait(for: [expectation], timeout: 10.0)

        self.workManager.workRequests.removeAll()
        self.apiClient.resetCallback = nil

        notificationCenter.post(
            Notification(name: AppStateTracker.didBecomeActiveNotification)
        )
        XCTAssertEqual(0, self.workManager.workRequests.count)
        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

    }

    func testChannelCreatedResolves() async throws {
        notificationCenter.post(Notification(name: AirshipChannel.channelCreatedEvent))

        XCTAssertEqual(1, self.workManager.workRequests.count)

        let expectation = XCTestExpectation(description: "callback called")
        self.apiClient.resolveCallback = { identifier in
            XCTAssertEqual("channel id", identifier)
            expectation.fulfill()
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: true
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)


        wait(for: [expectation], timeout: 10.0)
    }

    func testIdentify() async throws {
        self.contact.identify("cool user 1")

        XCTAssertEqual(1, self.workManager.workRequests.count)
        
        let expectation = XCTestExpectation(description: "callback called")
    
        self.apiClient.identifyCallback = {
            channelID,
            namedUserID,
            contactID in
            XCTAssertEqual("channel id", channelID)
            XCTAssertEqual("cool user 1", namedUserID)
            XCTAssertNil(contactID)
            expectation.fulfill()
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: false
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        wait(for: [expectation], timeout: 10.0)
    }

    func testReset() async throws {
        self.contact.reset()

        XCTAssertEqual(1, self.workManager.workRequests.count)

        let expectation = XCTestExpectation(description: "callback called")
        self.apiClient.resetCallback = { identifier in
            XCTAssertEqual("channel id", identifier)
            expectation.fulfill()
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: true
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        wait(for: [expectation], timeout: 10.0)
    }

    func testRegisterEmail() async throws {
        self.contact.registerEmail(
            "ua@airship.com",
            options: EmailRegistrationOptions.options(
                transactionalOptedIn: Date(),
                properties: ["interests": "newsletter"],
                doubleOptIn: true
            )
        )

        // Should resolve first
        let resolve = XCTestExpectation(description: "resolve contact")
        self.apiClient.resolveCallback = { identifier in
            XCTAssertEqual("channel id", identifier)
            resolve.fulfill()
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: true
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        var result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        wait(for: [resolve], timeout: 10.0)

        XCTAssertEqual(2, self.workManager.workRequests.count)

        // Then register email
        let expectation = XCTestExpectation(description: "callback called")
        
        self.apiClient.registerEmailCallback = {
            identifier,
            address,
            options in
            XCTAssertEqual("some-contact-id", identifier)
            XCTAssertEqual("ua@airship.com", address)
            XCTAssertNotNil(options)
            let channel = AssociatedChannel(
                channelType: .email,
                channelID: "some-channel-id"
            )
            expectation.fulfill()
            return AirshipHTTPResponse(
                result: channel,
                statusCode: 200,
                headers: [:]
            )
        }

        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        wait(for: [expectation], timeout: 10.0)
    }

    func testRegisterEmailFailed() async throws {
        self.contact.registerEmail(
            "ua@airship.com",
            options: EmailRegistrationOptions.options(
                transactionalOptedIn: Date(),
                properties: ["interests": "newsletter"],
                doubleOptIn: true
            )
        )

        // Should resolve first
        let resolve = XCTestExpectation(description: "resolve contact")
        self.apiClient.resolveCallback = { identifier in
            XCTAssertEqual("channel id", identifier)
            resolve.fulfill()
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: true
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        var result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        wait(for: [resolve], timeout: 10.0)

        XCTAssertEqual(2, self.workManager.workRequests.count)

        // Then register email
        let expectation = XCTestExpectation(description: "callback called")
        self.apiClient.registerEmailCallback = {
            identifier,
            address,
            options in
            XCTAssertEqual("some-contact-id", identifier)
            XCTAssertEqual("ua@airship.com", address)
            XCTAssertNotNil(options)
            _ = AssociatedChannel(
                channelType: .email,
                channelID: "some-channel-id"
            )
            expectation.fulfill()
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 500,
                headers: [:]
            )
        }

        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .failure)

        wait(for: [expectation], timeout: 10.0)
    }

    func testRegisterSMS() async throws {
        self.contact.registerSMS(
            "15035556789",
            options: SMSRegistrationOptions.optIn(senderID: "28855")
        )

        // Should resolve first
        let resolve = XCTestExpectation(description: "resolve contact")
        self.apiClient.resolveCallback = { identifier in
            XCTAssertEqual("channel id", identifier)
            resolve.fulfill()
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: true
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        var result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        wait(for: [resolve], timeout: 10.0)

        XCTAssertEqual(2, self.workManager.workRequests.count)

        // Then register sms
        let expectation = XCTestExpectation(description: "callback called")
      
        self.apiClient.registerSMSCallback = {
            identifier,
            msisdn,
            options in
            XCTAssertEqual("some-contact-id", identifier)
            XCTAssertEqual("15035556789", msisdn)
            XCTAssertNotNil(options)
            let channel = AssociatedChannel(
                channelType: .sms,
                channelID: "some-channel-id"
            )
            expectation.fulfill()
            return AirshipHTTPResponse(
                result: channel,
                statusCode: 200,
                headers: [:]
            )
        }

        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        wait(for: [expectation], timeout: 10.0)
    }

    func testRegisterSMSFailed() async throws {
        self.contact.registerSMS(
            "15035556789",
            options: SMSRegistrationOptions.optIn(senderID: "28855")
        )

        // Should resolve first
        let resolve = XCTestExpectation(description: "resolve contact")
        self.apiClient.resolveCallback = { identifier in
            XCTAssertEqual("channel id", identifier)
            resolve.fulfill()
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: true
                ),
                statusCode: 200,
                headers: [:]
            )
        }


        var result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        wait(for: [resolve], timeout: 10.0)

        XCTAssertEqual(2, self.workManager.workRequests.count)

        // Then register sms
        let expectation = XCTestExpectation(description: "callback called")
        self.apiClient.registerSMSCallback = {
            identifier,
            msisdn,
            options in
            expectation.fulfill()
            return AirshipHTTPResponse(
                result: nil,
                statusCode:500,
                headers: [:]
            )
        }

        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .failure)

        wait(for: [expectation], timeout: 10.0)
    }

    func testRegisterOpen() async throws {
        self.contact.registerOpen(
            "open_address",
            options: OpenRegistrationOptions.optIn(
                platformName: "my_platform",
                identifiers: ["model": "4"]
            )
        )

        // Should resolve first
        let resolve = XCTestExpectation(description: "resolve contact")
        self.apiClient.resolveCallback = { identifier in
            XCTAssertEqual("channel id", identifier)
            resolve.fulfill()
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: true
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        var result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        wait(for: [resolve], timeout: 10.0)

        XCTAssertEqual(2, self.workManager.workRequests.count)

        // Then register email
        let expectation = XCTestExpectation(description: "callback called")
        self.apiClient.registerOpenCallback = {
            identifier,
            address,
            options in
            XCTAssertEqual("some-contact-id", identifier)
            XCTAssertEqual("open_address", address)
            XCTAssertNotNil(options)
            let channel = AssociatedChannel(
                channelType: .email,
                channelID: "some-channel-id"
            )
            expectation.fulfill()
            return AirshipHTTPResponse(
                result: channel,
                statusCode:200,
                headers: [:]
            )
        }

        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        wait(for: [expectation], timeout: 10.0)
    }

    func testRegisterOpenFailed() async throws {
        self.contact.registerOpen(
            "open_address",
            options: OpenRegistrationOptions.optIn(
                platformName: "my_platform",
                identifiers: ["model": "4"]
            )
        )

        // Should resolve first
        let resolve = XCTestExpectation(description: "resolve contact")
        self.apiClient.resolveCallback = { identifier in
            XCTAssertEqual("channel id", identifier)
            resolve.fulfill()
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: true
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        var result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
        wait(for: [resolve], timeout: 10.0)

        XCTAssertEqual(2, self.workManager.workRequests.count)

        // Then register email
        let expectation = XCTestExpectation(description: "callback called")
        self.apiClient.registerOpenCallback = {
            identifier,
            address,
            options in
            expectation.fulfill()
            return AirshipHTTPResponse(
                result: nil,
                statusCode:500,
                headers: [:]
            )
        }

        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .failure)
        wait(for: [expectation], timeout: 10.0)
    }

    func testAssociateChannel() async throws {
        self.contact.associateChannel("some-channel-id", type: .email)

        // Should resolve first
        let resolve = XCTestExpectation(description: "resolve contact")
        self.apiClient.resolveCallback = { identifier in
            XCTAssertEqual("channel id", identifier)
            resolve.fulfill()
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: true
                ),
                statusCode: 200,
                headers: [:]
            )
        }
        
        var result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
        wait(for: [resolve], timeout: 10.0)

        XCTAssertEqual(2, self.workManager.workRequests.count)

        // Then associate
        let expectation = XCTestExpectation(description: "callback called")
        self.apiClient.associateChannelCallback = {
            identifier,
            channelID,
            channelType in
            XCTAssertEqual("some-contact-id", identifier)
            XCTAssertEqual("some-channel-id", channelID)
            XCTAssertEqual(.email, channelType)
            let channel = AssociatedChannel(
                channelType: .email,
                channelID: "some-channel-id"
            )
            expectation.fulfill()
            return AirshipHTTPResponse(
                result: channel,
                statusCode: 200,
                headers: [:]
            )
        }

        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
        wait(for: [expectation], timeout: 10.0)
    }

    func testAssociateChannelFailed() async throws {
        self.contact.associateChannel("some-channel-id", type: .email)

        // Should resolve first
        let resolve = XCTestExpectation(description: "resolve contact")
        self.apiClient.resolveCallback = { identifier in
            XCTAssertEqual("channel id", identifier)
            resolve.fulfill()
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: true
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        var result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
        wait(for: [resolve], timeout: 10.0)

        XCTAssertEqual(2, self.workManager.workRequests.count)

        // Then associate
        let expectation = XCTestExpectation(description: "callback called")
        self.apiClient.associateChannelCallback = {
            identifier,
            channelID,
            channelType in
            expectation.fulfill()
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 500,
                headers: [:]
            )
        }

        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .failure)
        wait(for: [expectation], timeout: 10.0)
    }

    func testResetsNotSkippedDuringIdentify() async throws {
        self.contact.identify("one")
        self.contact.reset()
        self.contact.reset()
        self.contact.identify("one")
        self.contact.reset()

        let identify = XCTestExpectation(description: "identify")
        identify.expectedFulfillmentCount = 2
        identify.assertForOverFulfill = true
        self.apiClient.identifyCallback = {
            channelID,
            namedUserID,
            contactID in
            identify.fulfill()
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: false
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        let reset = XCTestExpectation(description: "reset")
        reset.expectedFulfillmentCount = 2
        reset.assertForOverFulfill = true
        self.apiClient.resetCallback = { channelID in
            reset.fulfill()
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-other-id",
                    isAnonymous: true
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        // identify
        var result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
        // reset
        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
        // identify
        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
        // reset
        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
        // no-op
        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
        wait(for: [reset, identify], timeout: 10.0)
    }

    func testResetsNotSkippDuringUpdate() async throws {
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
        self.apiClient.resolveCallback = { channelID in
            XCTAssertEqual("channel id", channelID)
            resolve.fulfill()
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: true
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        let update = XCTestExpectation(description: "update")
        update.expectedFulfillmentCount = 2
        update.assertForOverFulfill = true
        self.apiClient.updateCallback = {
            contactID,
            tagUpdates,
            attributeUpdates,
            subscriptionListUpdates in
            update.fulfill()
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 200,
                headers: [:]
            )
        }

        let reset = XCTestExpectation(description: "reset")
        reset.expectedFulfillmentCount = 2
        reset.assertForOverFulfill = true
        self.apiClient.resetCallback = { channelID in
            reset.fulfill()
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-other-id",
                    isAnonymous: true
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        // resolve
        var result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
        // update
        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
        // reset
        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
        // update
        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
        // reset
        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
        // no-op
        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        wait(for: [resolve, reset, update], timeout: 10.0)
    }

    func testSkipSandwichedIdentifyCalls() async throws {
        self.contact.identify("one")
        self.contact.identify("two")
        self.contact.identify("three")
        self.contact.identify("four")

        XCTAssertEqual(4, self.workManager.workRequests.count)

        let firstCallback = XCTestExpectation(description: "callback called")
        self.apiClient.identifyCallback = {
            channelID,
            namedUserID,
            contactID in
            XCTAssertEqual("channel id", channelID)
            XCTAssertEqual("one", namedUserID)
            XCTAssertNil(contactID)
            firstCallback.fulfill()
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: false
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        var result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        wait(for: [firstCallback], timeout: 10.0)
        XCTAssertEqual(5, self.workManager.workRequests.count)

        let secondCallback = XCTestExpectation(description: "callback called")
        self.apiClient.identifyCallback = {
            channelID,
            namedUserID,
            contactID in
            XCTAssertEqual("channel id", channelID)
            XCTAssertEqual("four", namedUserID)
            XCTAssertNil(contactID)
            secondCallback.fulfill()
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-other-contact-id",
                    isAnonymous: false
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        wait(for: [secondCallback], timeout: 10.0)
        XCTAssertEqual(5, self.workManager.workRequests.count)
    }

    func testCombineSequentialUpdates() async throws {
        self.contact.editTagGroups { editor in
            editor.add(["neat"], group: "cool")
        }
        XCTAssertEqual(1, self.workManager.workRequests.count)

        self.contact.editAttributes { editor in
            editor.set(int: 1, attribute: "one")
        }
        XCTAssertEqual(2, self.workManager.workRequests.count)

        self.contact.editSubscriptionLists { editor in
            editor.subscribe("some list", scope: .app)
        }
        XCTAssertEqual(3, self.workManager.workRequests.count)

        // Should resolve first
        let resolve = XCTestExpectation(description: "resolve contact")
        self.apiClient.resolveCallback = { channelID in
            XCTAssertEqual("channel id", channelID)
            resolve.fulfill()
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: false
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        var result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        wait(for: [resolve], timeout: 10.0)

        // Then update
        let update = XCTestExpectation(description: "callback called")
        self.apiClient.updateCallback = {
            contactID,
            tagUpdates,
            attributeUpdates,
            subscriptionListUpdates in
            XCTAssertEqual("some-contact-id", contactID)
            XCTAssertEqual(1, tagUpdates?.count ?? 0)
            XCTAssertEqual(1, attributeUpdates?.count ?? 0)
            XCTAssertEqual(1, subscriptionListUpdates?.count ?? 0)
            update.fulfill()
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 200,
                headers: [:]
            )
        }

        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        wait(for: [update], timeout: 10.0)

        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

    }

    func testSkipResolves() async throws {
        self.contact.identify("one")
        notificationCenter.post(Notification(name: AirshipChannel.channelCreatedEvent))
        notificationCenter.post(Notification(name: AirshipChannel.channelCreatedEvent))
        notificationCenter.post(Notification(name: AirshipChannel.channelCreatedEvent))
        notificationCenter.post(Notification(name: AirshipChannel.channelCreatedEvent))
        notificationCenter.post(Notification(name: AirshipChannel.channelCreatedEvent))

        self.apiClient.resolveCallback = { channelID in
            XCTFail()
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 200,
                headers: [:]
            )
        }

        let identifyCallback = XCTestExpectation(description: "callback called")
        self.apiClient.identifyCallback = {
            channelID,
            namedUserID,
            contactID in
            XCTAssertEqual("channel id", channelID)
            XCTAssertEqual("one", namedUserID)
            XCTAssertNil(contactID)
            identifyCallback.fulfill()
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: false
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        var result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        wait(for: [identifyCallback], timeout: 10.0)

        // queue should be empty
        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

    }

    func testConflictOnIdentify() async throws {
        self.apiClient.resolveCallback = { channelID in
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: true
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        self.apiClient.updateCallback = {
            contactID,
            tagUpdates,
            attributeUpdates,
            subscriptionListsUpdates in
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 200,
                headers: [:]
            )
        }

        self.apiClient.identifyCallback = {
            channelID,
            namedUserID,
            contactID in
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-other-contact-id",
                    isAnonymous: false
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        let delegate = TestDelegate()
        let conflictCalled = XCTestExpectation(description: "conflict called")

        delegate.onConflictBlock = { data, namedUserID in
            XCTAssertEqual("some-user", namedUserID)
            XCTAssertEqual(
                ["cool": ["neat"]] as NSDictionary,
                data.tags as NSDictionary
            )
            XCTAssertEqual(
                ["one": 1] as NSDictionary,
                data.attributes as NSDictionary
            )
            XCTAssertEqual(
                ["foo": ChannelScopes([.app])],
                data.subscriptionLists
            )

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
        var result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
        // tags
        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
        // attributes
        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
        // identify
        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        wait(for: [conflictCalled], timeout: 10.0)
    }

    func testConflictOnResolve() async throws {
        var first = true
        self.apiClient.resolveCallback = { channelID in
            if first {
                first = false
                return AirshipHTTPResponse(
                    result: ContactAPIResponse(
                        contactID: "some-contact-id",
                        isAnonymous: true
                    ),
                    statusCode: 200,
                    headers: [:]
                )
            } else {
                return AirshipHTTPResponse(
                    result: ContactAPIResponse(
                        contactID: "some-other-contact-id",
                        isAnonymous: true
                    ),
                    statusCode: 200,
                    headers: [:]
                )
            }
        }

        self.apiClient.updateCallback = {
            contactID,
            tagUpdates,
            attributeUpdates,
            subscriptionListsUpdates in
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 200,
                headers: [:]
            )
        }

        let delegate = TestDelegate()
        let conflictCalled = XCTestExpectation(description: "conflict called")

        delegate.onConflictBlock = { data, namedUserID in
            XCTAssertNil(namedUserID)
            XCTAssertEqual(
                ["cool": ["neat"]] as NSDictionary,
                data.tags as NSDictionary
            )
            XCTAssertEqual(
                ["one": 1] as NSDictionary,
                data.attributes as NSDictionary
            )
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
        var result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
        // tags
        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
        // attributes
        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
        // resolve with conflict
        notificationCenter.post(Notification(name: AirshipChannel.channelCreatedEvent))
        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        wait(for: [conflictCalled], timeout: 10.0)
    }

    func testResolveSkippedContactsDisabled() async throws {
        self.privacyManager.disableFeatures(.contacts)

        notificationCenter.post(Notification(name: AirshipChannel.channelCreatedEvent))
        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
    }

    func testTagsAndAttributesSkippedContactsDisabled() async throws {
        self.privacyManager.disableFeatures(.contacts)

        let tagEdits = self.contact.editTagGroups()
        tagEdits.add(["neat"], group: "cool")
        tagEdits.apply()

        let attributeEdits = self.contact.editAttributes()
        attributeEdits.set(int: 1, attribute: "one")
        attributeEdits.apply()

        var result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        self.privacyManager.disableFeatures(.tagsAndAttributes)
        self.privacyManager.enableFeatures(.contacts)

        tagEdits.apply()
        attributeEdits.apply()

        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
    }

    func testIdentifySkippedContactsDisabled() async throws {
        self.privacyManager.disableFeatures(.contacts)

        self.contact.identify("cat")

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
    }

    func testResetOnDisbleContacts() async throws {
        self.contact.identify("cat")
        self.apiClient.identifyCallback = {
            channelID,
            namedUserID,
            contactID in
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: false
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        // identify
        var result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        let expectation = XCTestExpectation(description: "callback called")
        self.apiClient.resetCallback = { channelID in
            XCTAssertEqual("channel id", channelID)
            expectation.fulfill()
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: true
                ),
                statusCode: 200,
                headers: [:]
            )
        }
        
       
        self.privacyManager.disableFeatures(.contacts)
        notificationCenter.post(
            name: AirshipPrivacyManager.changeEvent,
            object: nil
        )
            
        // reset
        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
        
        wait(for: [expectation], timeout: 10.0)
    }

    func testIdentifyFailed() async throws {
        self.contact.identify("cool user 1")

        let expectation = XCTestExpectation(description: "callback called")
        expectation.expectedFulfillmentCount = 2
        self.apiClient.identifyCallback = {
            channelID,
            namedUserID,
            contactID in
            expectation.fulfill()
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: nil,
                    isAnonymous: nil
                ),
                statusCode: 500,
                headers: [:]
            )
        }

        var result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .failure)
        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .failure)
        wait(for: [expectation], timeout: 10.0)
    }

    func testResetFailed() async throws {
        self.contact.reset()

        let expectation = XCTestExpectation(description: "callback called")
        expectation.expectedFulfillmentCount = 2
        self.apiClient.resetCallback = { channelID in
            expectation.fulfill()
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: nil,
                    isAnonymous: nil
                ),
                statusCode: 505,
                headers: [:]
            )
        }

        var result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .failure)
        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .failure)

        wait(for: [expectation], timeout: 10.0)
    }

    func testUpdateFailed() async throws {
        let attributeEdits = self.contact.editAttributes()
        attributeEdits.set(int: 1, attribute: "one")
        attributeEdits.apply()

        self.apiClient.resolveCallback = { channelID in
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: true
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        var result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        let expectation = XCTestExpectation(description: "callback called")
        expectation.expectedFulfillmentCount = 2
        self.apiClient.updateCallback = {
            contactID,
            tagUpdates,
            attributeUpdates,
            subscriptionListsUpdates in
            expectation.fulfill()
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 500,
                headers: [:]
            )
        }

        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .failure)
        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .failure)

        wait(for: [expectation], timeout: 10.0)
    }

    func testResolveFailed() async throws {
        notificationCenter.post(
            Notification(name: AppStateTracker.didBecomeActiveNotification)
        )

        let expectation = XCTestExpectation(description: "resolve contact")
        expectation.expectedFulfillmentCount = 2

        self.apiClient.resolveCallback = { channelID in
            expectation.fulfill()
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 505,
                headers: [:]
            )
        }

        var result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .failure)
        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .failure)

        wait(for: [expectation], timeout: 10.0)
    }

    func testFetchSubscriptionLists() async throws {
        // Resolve the contact ID
        notificationCenter.post(
            Notification(name: AppStateTracker.didBecomeActiveNotification)
        )
        XCTAssertEqual(1, self.workManager.workRequests.count)
        self.apiClient.resolveCallback = { channelID in
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: true
                ),
                statusCode: 200,
                headers: [:]
            )
        }
        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        let apiResult: [String: [ChannelScope]] = ["neat": [.web]]
        let expected = AudienceUtils.wrap(apiResult)
        self.apiClient.fetchSubscriptionListsCallback = {
            identifier in
            XCTAssertEqual("some-contact-id", identifier)
            return AirshipHTTPResponse(
                result: apiResult,
                statusCode: 200,
                headers: [:]
            )
        }

        let expectation = XCTestExpectation(description: "callback called")
        let lists:[String: ChannelScopes] = try await self.contact.fetchSubscriptionLists()
        XCTAssertEqual(expected, lists)
        expectation.fulfill()

        wait(for: [expectation], timeout: 10.0)
    }

    func testFetchSubscriptionListsPendingReset() async throws {
        // Resolve the contact ID
        notificationCenter.post(
            Notification(name: AppStateTracker.didBecomeActiveNotification)
        )
        XCTAssertEqual(1, self.workManager.workRequests.count)
        self.apiClient.resolveCallback = { channelID in
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: true
                ),
                statusCode: 200,
                headers: [:]
            )
        }
        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        // Apply an update to current contact, to avoid skipping reset
        self.contact.editSubscriptionLists { editor in
            editor.subscribe("neat", scope: .email)
        }
        self.contact.reset()

        do {
            let _:[String: ChannelScopes] = try await self.contact.fetchSubscriptionLists()
            XCTFail()
        }
        catch {
            
        }
    }

    func testFetchSubscriptionListsPendingIdentify() async throws {
        // Resolve the contact ID
        notificationCenter.post(
            Notification(name: AppStateTracker.didBecomeActiveNotification)
        )
        XCTAssertEqual(1, self.workManager.workRequests.count)
        self.apiClient.resolveCallback = { channelID in
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: true
                ),
                statusCode: 200,
                headers: [:]
            )
        }
        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        // Reset the contact
        self.contact.identify("some user")

        do {
            let _:[String: ChannelScopes] = try await self.contact.fetchSubscriptionLists()
            XCTFail()
        }
        catch {
            
        }
    }

    func testFetchSubscriptionListsNoContact() async throws {
        do {
            let _:[String: ChannelScopes] = try await self.contact.fetchSubscriptionLists()
            XCTFail()
        }
        catch {
            
        }
    }

    func testFetchSubscriptionListsCached() async throws {
        self.date.dateOverride = Date()

        // Resolve the contact ID
        notificationCenter.post(
            Notification(name: AppStateTracker.didBecomeActiveNotification)
        )
        XCTAssertEqual(1, self.workManager.workRequests.count)
        self.apiClient.resolveCallback = { channelID in
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: true
                ),
                statusCode: 200,
                headers: [:]
            )
        }
        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)


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
        var expectation = XCTestExpectation(description: "callback called")
        var lists:[String: ChannelScopes] = try await self.contact.fetchSubscriptionLists()
      
        XCTAssertEqual(AudienceUtils.wrap(expected), lists)
        expectation.fulfill()
    

        wait(for: [expectation], timeout: 10.0)

        apiResult = ["something else": [.web]]

        // From cache
        expectation = XCTestExpectation(description: "callback called")
        lists = try await self.contact.fetchSubscriptionLists()
      
        XCTAssertEqual(AudienceUtils.wrap(expected), lists)
        expectation.fulfill()
    
        wait(for: [expectation], timeout: 10.0)

        self.date.offset += 599  // 1 second before cache should invalidate

        // From cache
        expectation = XCTestExpectation(description: "callback called")
        lists = try await self.contact.fetchSubscriptionLists()
      
        XCTAssertEqual(AudienceUtils.wrap(expected), lists)
        expectation.fulfill()
    
        wait(for: [expectation], timeout: 10.0)

        self.date.offset += 1

        // From api
        expected = apiResult
        expectation = XCTestExpectation(description: "callback called")
        lists = try await self.contact.fetchSubscriptionLists()
      
        XCTAssertEqual(AudienceUtils.wrap(expected), lists)
        expectation.fulfill()
    
        wait(for: [expectation], timeout: 10.0)
    }

    func testFetchSubscriptionListsCachedDifferentContactID() async throws {
        self.date.dateOverride = Date()

        // Resolve the contact ID
        notificationCenter.post(
            Notification(name: AppStateTracker.didBecomeActiveNotification)
        )
        XCTAssertEqual(1, self.workManager.workRequests.count)
        self.apiClient.resolveCallback = { channelID in
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: true
                ),
                statusCode: 200,
                headers: [:]
            )
        }
        var result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
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
        var lists:[String: ChannelScopes] = try await self.contact.fetchSubscriptionLists()
      
        XCTAssertEqual(AudienceUtils.wrap(expected), lists)

        apiResult = ["something else": [.web]]

        // From cache
        lists = try await self.contact.fetchSubscriptionLists()
      
        XCTAssertEqual(AudienceUtils.wrap(expected), lists)
        let expectation = XCTestExpectation(description: "callback called")
        // Resolve a new contact ID
        contact.identify("some user")
        self.apiClient.identifyCallback = {
            channelID,
            namedUserID,
            contactID in
            expectation.fulfill()
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-other-contact-id",
                    isAnonymous: false
                ),
                statusCode: 200,
                headers: [:]
            )
        }
        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

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
      
        XCTAssertEqual(AudienceUtils.wrap(expected), lists)
    }

    func testFetchSubscriptionListsPendingApplied() async throws {
        // Resolve the contact ID
        notificationCenter.post(
            Notification(name: AppStateTracker.didBecomeActiveNotification)
        )
        XCTAssertEqual(1, self.workManager.workRequests.count)
        self.apiClient.resolveCallback = { channelID in
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: true
                ),
                statusCode: 200,
                headers: [:]
            )
        }
        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        let apiResult: [String: [ChannelScope]] = ["foo": [.web, .sms]]
        self.apiClient.fetchSubscriptionListsCallback = {
            identifier in
            XCTAssertEqual("some-contact-id", identifier)
            return AirshipHTTPResponse(
                result: apiResult,
                statusCode: 200,
                headers: [:]
            )
        }

        self.contact.editSubscriptionLists { editor in
            editor.subscribe("bar", scope: .app)
            editor.unsubscribe("foo", scope: .sms)
        }

        let expected: [String: [ChannelScope]] = ["foo": [.web], "bar": [.app]]
        let expectation = XCTestExpectation(description: "callback called")
        let lists:[String: ChannelScopes] = try await self.contact.fetchSubscriptionLists()
      
        XCTAssertEqual(AudienceUtils.wrap(expected), lists)
        expectation.fulfill()


        wait(for: [expectation], timeout: 10.0)
    }

    func testFetchSubscriptionListsLocalHistoryApplied() async throws {
        // Resolve the contact ID
        notificationCenter.post(
            Notification(name: AppStateTracker.didBecomeActiveNotification)
        )
        XCTAssertEqual(1, self.workManager.workRequests.count)
        self.apiClient.resolveCallback = { channelID in
            return AirshipHTTPResponse(
                result: ContactAPIResponse(
                    contactID: "some-contact-id",
                    isAnonymous: true
                ),
                statusCode: 200,
                headers: [:]
            )
        }
        var result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        self.contact.editSubscriptionLists { editor in
            editor.subscribe("bar", scope: .app)
        }

        // Apply update
        let update = XCTestExpectation(description: "update")
        self.apiClient.updateCallback = {
            contactID,
            tagUpdates,
            attributeUpdates,
            subscriptionListUpdates in
            update.fulfill()
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 200,
                headers: [:]
            )
        }
        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: AirshipContact.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
        wait(for: [update], timeout: 10.0)

        XCTAssertTrue(self.contact.pendingSubscriptionListUpdates.isEmpty)

        let apiResult: [String: [ChannelScope]] = ["foo": [.web]]
        self.apiClient.fetchSubscriptionListsCallback = {
            identifier in
            XCTAssertEqual("some-contact-id", identifier)
            return AirshipHTTPResponse(
                result: apiResult,
                statusCode: 200,
                headers: [:]
            )
        }

        let expected: [String: [ChannelScope]] = ["foo": [.web], "bar": [.app]]
        let expectation = XCTestExpectation(description: "callback called")
        let lists:[String: ChannelScopes] = try await self.contact.fetchSubscriptionLists()
      
        XCTAssertEqual(AudienceUtils.wrap(expected), lists)
        expectation.fulfill()

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
            SubscriptionListUpdate(listId: "baz", type: .unsubscribe),
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
            SubscriptionListUpdate(listId: "baz", type: .unsubscribe),
        ]

        XCTAssertEqual(expectedUpdates, self.channel.contactUpdates)
    }

    func testSubscriptionListEdits() throws {
        var edits = [ScopedSubscriptionListEdit]()

        let expectation = self.expectation(description: "Publisher")
        expectation.expectedFulfillmentCount = 3
        let cancellable = self.contact.subscriptionListEdits.sink {
            edits.append($0)
            expectation.fulfill()
        }

        self.contact.editSubscriptionLists { editor in
            editor.unsubscribe("pen", scope: .web)
            editor.unsubscribe("pinapple", scope: .app)
            editor.subscribe("pinapple pen", scope: .email)
        }

        self.waitForExpectations(timeout: 10.0)

        let expected: [ScopedSubscriptionListEdit] = [
            .unsubscribe("pen", .web),
            .unsubscribe("pinapple", .app),
            .subscribe("pinapple pen", .email),
        ]

        XCTAssertEqual(expected, edits)
        cancellable.cancel()
    }
}
