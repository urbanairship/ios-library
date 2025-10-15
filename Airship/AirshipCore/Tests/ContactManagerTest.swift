import Testing

@testable
import AirshipCore

@Suite(.timeLimit(.minutes(1)))
struct ContactManagerTest {

    let date: UATestDate
    let channel: TestChannel
    let localeManager: TestLocaleManager
    let workManager: TestWorkManager
    let dataStore: PreferenceDataStore
    let apiClient: TestContactAPIClient
    let contactManager: ContactManager

    let anonIdentifyResponse: ContactIdentifyResult
    let nonAnonIdentifyResponse: ContactIdentifyResult

    // Helper to wait for async conditions with timeout
    private func waitForCondition(
        timeout: Duration = .seconds(2),
        pollingInterval: Duration = .milliseconds(10),
        condition: @escaping () async -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if await condition() { return }
            try await Task.sleep(for: pollingInterval)
        }
        throw NSError(domain: "TestTimeout", code: 1, userInfo: [NSLocalizedDescriptionKey: "Condition not met within timeout"])
    }

    init() async throws {
        self.date = UATestDate(offset: 0, dateOverride: Date())
        self.channel = TestChannel()
        self.localeManager = TestLocaleManager()
        self.workManager = TestWorkManager()
        self.dataStore = PreferenceDataStore(appKey: UUID().uuidString)
        self.apiClient = TestContactAPIClient()

        self.anonIdentifyResponse = ContactIdentifyResult(
            contact: ContactIdentifyResult.ContactInfo(
                channelAssociatedDate: AirshipDateFormatter.date(fromISOString: "2022-12-29T10:15:30.00")!,
                contactID: "some contact",
                isAnonymous: true
            ),
            token: "some token",
            tokenExpiresInMilliseconds: 3600000
        )

        self.nonAnonIdentifyResponse = ContactIdentifyResult(
            contact: ContactIdentifyResult.ContactInfo(
                channelAssociatedDate: AirshipDateFormatter.date(fromISOString: "2022-12-29T10:15:30.00")!,
                contactID: "some other contact",
                isAnonymous: false
            ),
            token: "some other token",
            tokenExpiresInMilliseconds: 3600000
        )

        self.localeManager.currentLocale = Locale(identifier: "fr-CA")

        self.contactManager = ContactManager(
            dataStore: self.dataStore,
            channel: self.channel,
            localeManager: self.localeManager,
            apiClient: self.apiClient,
            date: self.date,
            workManager: self.workManager,
            internalIdentifyRateLimit: 0.0
        )

        await self.contactManager.setEnabled(enabled: true)
        self.channel.identifier = "some channel"
    }

    @Test("Enable enqueues work")
    func enableEnqueuesWork() async throws {
        await self.contactManager.setEnabled(enabled: false)
        #expect(self.workManager.workRequests.isEmpty)

        await self.contactManager.addOperation(.resolve)

        await self.contactManager.setEnabled(enabled: false)
        #expect(self.workManager.workRequests.isEmpty)

        await self.contactManager.setEnabled(enabled: true)
        #expect(!self.workManager.workRequests.isEmpty)
    }

    @Test("Channel creation enqueues work")
    func channelCreationEnqueuesWork() async throws {
        await self.contactManager.setEnabled(enabled: true)

        // Clear the channel identifier to simulate no channel
        self.channel.identifier = nil

        // Wait a moment for that to process
        try await Task.sleep(for: .milliseconds(100))

        // Track initial work count
        let initialWorkCount = self.workManager.workRequests.count

        // Simulate channel creation by setting identifier
        self.channel.identifier = "newly-created-channel-id"

        // Wait for new work to be enqueued
        try await waitForCondition(timeout: .seconds(5)) {
            self.workManager.workRequests.count > initialWorkCount
        }

        // Verify new work was enqueued
        #expect(self.workManager.workRequests.count > initialWorkCount)
    }

    @Test("Add operation enqueues work")
    func addOperationEnqueuesWork() async throws {
        await self.contactManager.setEnabled(enabled: true)
        #expect(self.workManager.workRequests.isEmpty)

        await self.contactManager.addOperation(.resolve)
        #expect(!self.workManager.workRequests.isEmpty)
    }

    @Test("Add skippable operation enqueues work")
    func addSkippableOperationEnqueuesWork() async throws {
        await self.contactManager.setEnabled(enabled: true)
        await self.contactManager.addOperation(.resolve)

        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )
        #expect(result == .success)
        self.workManager.workRequests.removeAll()

        await self.contactManager.addOperation(.reset)
        #expect(!self.workManager.workRequests.isEmpty)
    }

    @Test("Rate limit config")
    func rateLimitConfig() async throws {
        let rateLimits = self.workManager.rateLimits
        #expect(rateLimits.count == 2)

        let updateRule = rateLimits[ContactManager.updateRateLimitID]!
        #expect(updateRule.rate == 1)
        #expect(abs(updateRule.timeInterval - 0.5) < 0.01)


        let identityRule = rateLimits[ContactManager.identityRateLimitID]!
        #expect(identityRule.rate == 1)
        #expect(abs(identityRule.timeInterval - 5.0) < 0.01)
    }

    @Test("Resolve")
    func resolve() async throws {
        await self.contactManager.addOperation(.resolve)

        try await confirmation { confirm in
            self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
                #expect(self.channel.identifier == channelID)
                #expect(contactID == nil)
                confirm()
                return AirshipHTTPResponse(
                    result: self.anonIdentifyResponse,
                    statusCode: 200,
                    headers: [:]
                )
            }

            let result = try await self.workManager.launchTask(
                request: AirshipWorkRequest(
                    workID: ContactManager.updateTaskID
                )
            )

            #expect(result == .success)
        }

        let contactInfo = await self.contactManager.currentContactIDInfo()
        #expect(anonIdentifyResponse.contact.contactID == contactInfo?.contactID)

        await self.verifyUpdates([
            .contactIDUpdate(
                ContactIDInfo(
                    contactID: self.anonIdentifyResponse.contact.contactID,
                    isStable: true,
                    namedUserID: nil,
                    resolveDate: self.date.now
                )
            )
        ])
    }

    @Test("Resolve with contact ID")
    func resolveWithContactID() async throws {
        await self.contactManager.generateDefaultContactIDIfNotSet()
        await self.contactManager.addOperation(.resolve)

        try await confirmation { confirm in
            self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
                #expect(self.channel.identifier == channelID)
                #expect(contactID != nil)
                confirm()
                return AirshipHTTPResponse(
                    result: self.anonIdentifyResponse,
                    statusCode: 200,
                    headers: [:]
                )
            }

            let result = try await self.workManager.launchTask(
                request: AirshipWorkRequest(
                    workID: ContactManager.updateTaskID
                )
            )

            #expect(result == .success)
        }

        let contactInfo = await self.contactManager.currentContactIDInfo()
        #expect(anonIdentifyResponse.contact.contactID == contactInfo?.contactID)
    }

    @Test("Resolved failed")
    func resolvedFailed() async throws {
        await self.contactManager.addOperation(.resolve)
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 500,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )

        #expect(result == .failure)
    }

    @Test("Verify")
    func verify() async throws {
        await self.contactManager.addOperation(.verify(self.date.now))

        try await confirmation { confirm in
            self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
                #expect(self.channel.identifier == channelID)
                #expect(contactID == nil)
                confirm()
                return AirshipHTTPResponse(
                    result: self.anonIdentifyResponse,
                    statusCode: 200,
                    headers: [:]
                )
            }

            let result = try await self.workManager.launchTask(
                request: AirshipWorkRequest(
                    workID: ContactManager.updateTaskID
                )
            )

            #expect(result == .success)
        }

        let contactInfo = await self.contactManager.currentContactIDInfo()
        #expect(anonIdentifyResponse.contact.contactID == contactInfo?.contactID)

        await self.verifyUpdates([
            .contactIDUpdate(
                ContactIDInfo(
                    contactID: self.anonIdentifyResponse.contact.contactID,
                    isStable: true,
                    namedUserID: nil,
                    resolveDate: self.date.now
                )
            )
        ])
    }

    @Test("Required verify")
    func requiredVerify() async throws {
        // Resolve is called first if we do not have a valid token
        try await confirmation { confirm in
            self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
                #expect(self.channel.identifier == channelID)
                #expect(contactID == nil)
                confirm()
                return AirshipHTTPResponse(
                    result: self.anonIdentifyResponse,
                    statusCode: 200,
                    headers: [:]
                )
            }

            await self.contactManager.addOperation(.resolve)
            _ = try await self.workManager.launchTask(
                request: AirshipWorkRequest(
                    workID: ContactManager.updateTaskID
                )
            )
        }

        await self.contactManager.addOperation(.verify(self.date.now + 1, required: true))

        await self.verifyUpdates(
            [
                .contactIDUpdate(
                    ContactIDInfo(
                        contactID: self.anonIdentifyResponse.contact.contactID,
                        isStable: true,
                        namedUserID: nil,
                        resolveDate: self.date.now
                    )
                ),
                .contactIDUpdate(
                    ContactIDInfo(
                        contactID: self.anonIdentifyResponse.contact.contactID,
                        isStable: false,
                        namedUserID: nil,
                        resolveDate: self.date.now
                    )
                )
            ]
        )
    }

    @Test("Verify failed")
    func verifyFailed() async throws {
        await self.contactManager.addOperation(.verify(self.date.now))
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 500,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )

        #expect(result == .failure)
    }

    @Test("Resolved failed client error")
    func resolvedFailedClientError() async throws {
        await self.contactManager.addOperation(.resolve)
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 400,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )

        #expect(result == .success)
    }

    @Test("Identify")
    func identify() async throws {
        await self.contactManager.addOperation(.identify("some named user"))
        await self.verifyUpdates([.namedUserUpdate("some named user")])

        // Resolve is called first if we do not have a valid token
        let resolveExpectation = expectation(description: "resolve contact")
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            #expect(self.channel.identifier == channelID)
            #expect(contactID == nil)
            resolveExpectation.fulfill()
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        try await confirmation { confirm in
            self.apiClient.identifyCallback = { channelID, namedUserID, contactID, possiblyOrphanedContactID in
                #expect(self.channel.identifier == channelID)
                #expect("some named user" == namedUserID)
                #expect(self.anonIdentifyResponse.contact.contactID == contactID)
                confirm()
                return AirshipHTTPResponse(
                    result: self.nonAnonIdentifyResponse,
                    statusCode: 200,
                    headers: [:]
                )
            }

            let result = try await self.workManager.launchTask(
                request: AirshipWorkRequest(
                    workID: ContactManager.updateTaskID
                )
            )

            #expect(result == .success)
        }

        await resolveExpectation.fulfillment

        let contactInfo = await self.contactManager.currentContactIDInfo()
        #expect(nonAnonIdentifyResponse.contact.contactID == contactInfo?.contactID)

        await self.verifyUpdates(
            [
                .contactIDUpdate(
                    ContactIDInfo(
                        contactID: self.anonIdentifyResponse.contact.contactID,
                        isStable: false,
                        namedUserID: nil,
                        resolveDate: self.date.now
                    )
                ),
                .contactIDUpdate(
                    ContactIDInfo(
                        contactID: self.nonAnonIdentifyResponse.contact.contactID,
                        isStable: true,
                        namedUserID: "some named user",
                        resolveDate: self.date.now
                    )
                ),
            ]
        )
    }

    @Test("Identify failed")
    func identifyFailed() async throws {
        await self.contactManager.addOperation(.identify("some named user"))

        // Resolve is called first if we do not have a valid token
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            #expect(self.channel.identifier == channelID)
            #expect(contactID == nil)
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        self.apiClient.identifyCallback = { channelID, namedUserID, contactID, possiblyOrphanedContactID in
            return AirshipHTTPResponse(
                result: self.nonAnonIdentifyResponse,
                statusCode: 500,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )

        #expect(result == .failure)
    }

    @Test("Identify failed client error")
    func identifyFailedClientError() async throws {
        await self.contactManager.addOperation(.identify("some named user"))

        // Resolve is called first if we do not have a valid token
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            #expect(self.channel.identifier == channelID)
            #expect(contactID == nil)
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        self.apiClient.identifyCallback = { channelID, namedUserID, contactID, possiblyOrphanedContactID in
            return AirshipHTTPResponse(
                result: self.nonAnonIdentifyResponse,
                statusCode: 400,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )

        #expect(result == .success)
    }

    @Test("Reset")
    func reset() async throws {
        await self.contactManager.addOperation(.reset)

        // Resolve is called first if we do not have a valid token
        let resolveExpectation = expectation(description: "resolve contact")
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            #expect(self.channel.identifier == channelID)
            #expect(contactID == nil)
            resolveExpectation.fulfill()
            return AirshipHTTPResponse(
                result: self.nonAnonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        try await confirmation { confirm in
            self.apiClient.resetCallback = { channelID, possiblyOrphanedContactID in
                #expect(self.channel.identifier == channelID)
                confirm()
                return AirshipHTTPResponse(
                    result: self.anonIdentifyResponse,
                    statusCode: 200,
                    headers: [:]
                )
            }

            let result = try await self.workManager.launchTask(
                request: AirshipWorkRequest(
                    workID: ContactManager.updateTaskID
                )
            )

            #expect(result == .success)
        }

        await resolveExpectation.fulfillment

        await self.verifyUpdates(
            [
                .contactIDUpdate(
                    ContactIDInfo(
                        contactID: self.nonAnonIdentifyResponse.contact.contactID,
                        isStable: false,
                        namedUserID: nil,
                        resolveDate: self.date.now
                    )
                ),
                .contactIDUpdate(
                    ContactIDInfo(
                        contactID: self.anonIdentifyResponse.contact.contactID,
                        isStable: true,
                        namedUserID: nil,
                        resolveDate: self.date.now
                    )
                )
            ]
        )
    }

    @Test("Reset if needed")
    func resetIfNeeded() async throws {
        let info = await self.contactManager.currentContactIDInfo()
        #expect(info == nil)

        await self.contactManager.resetIfNeeded()

        // Resolve is called first if we do not have a valid token
        let resolveExpectation = expectation(description: "resolve contact")
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            #expect(self.channel.identifier == channelID)
            #expect(contactID == nil)
            resolveExpectation.fulfill()
            return AirshipHTTPResponse(
                result: self.nonAnonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        try await confirmation { confirm in
            self.apiClient.resetCallback = { channelID, possiblyOrphanedContactID in
                #expect(self.channel.identifier == channelID)
                confirm()
                return AirshipHTTPResponse(
                    result: self.anonIdentifyResponse,
                    statusCode: 200,
                    headers: [:]
                )
            }

            let result = try await self.workManager.launchTask(
                request: AirshipWorkRequest(
                    workID: ContactManager.updateTaskID
                )
            )

            #expect(result == .success)
        }

        await resolveExpectation.fulfillment

        await self.verifyUpdates(
            [
                .contactIDUpdate(
                    ContactIDInfo(
                        contactID: self.nonAnonIdentifyResponse.contact.contactID,
                        isStable: false,
                        namedUserID: nil,
                        resolveDate: self.date.now
                    )
                ),
                .contactIDUpdate(
                    ContactIDInfo(
                        contactID: self.anonIdentifyResponse.contact.contactID,
                        isStable: true,
                        namedUserID: nil,
                        resolveDate: self.date.now
                    )
                )
            ]
        )
    }

    @Test("Auth token no contact info")
    func authTokenNoContactInfo() async throws {
        try await confirmation { confirm in
            self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
                #expect(self.channel.identifier == channelID)
                confirm()
                return AirshipHTTPResponse(
                    result: self.anonIdentifyResponse,
                    statusCode: 200,
                    headers: [:]
                )
            }

            let authToken = try await self.contactManager.resolveAuth(
                identifier: self.anonIdentifyResponse.contact.contactID
            )
            #expect(authToken == self.anonIdentifyResponse.token)
        }

        await self.verifyUpdates([
            .contactIDUpdate(
                ContactIDInfo(
                    contactID: self.anonIdentifyResponse.contact.contactID,
                    isStable: true,
                    namedUserID: nil,
                    resolveDate: self.date.now
                )
            )
        ])
    }

    @Test("Auth token valid token mismatch contact ID")
    func authTokenValidTokenMismatchContactID() async throws {
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        await self.contactManager.addOperation(.resolve)
        let _ = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )

        do {
            let _ = try await self.contactManager.resolveAuth(
                identifier: "some other contactID"
            )
            Issue.record("Should throw")
        } catch {}

    }

    @Test("Auth token resolve mismatch")
    func authTokenResolveMismatch() async throws {
        try await confirmation { confirm in
            self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
                #expect(self.channel.identifier == channelID)
                confirm()
                return AirshipHTTPResponse(
                    result: self.anonIdentifyResponse,
                    statusCode: 200,
                    headers: [:]
                )
            }

            do {
                let _ = try await self.contactManager.resolveAuth(
                    identifier: "some other contactID"
                )
                Issue.record("Should throw")
            } catch {}
        }
    }

    @Test("Expire auth token")
    func expireAuthToken() async throws {
        let resolveExpectation = expectation(description: "resolve contact", expectedFulfillmentCount: 2)

        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            #expect(self.channel.identifier == channelID)
            resolveExpectation.fulfill()
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }


        var authToken = try await self.contactManager.resolveAuth(
            identifier: self.anonIdentifyResponse.contact.contactID
        )

        await self.contactManager.authTokenExpired(token: authToken)

        authToken = try await self.contactManager.resolveAuth(
            identifier: self.anonIdentifyResponse.contact.contactID
        )

        #expect(authToken == self.anonIdentifyResponse.token)

        await resolveExpectation.fulfillment
    }

    @Test("Auth token failed")
    func authTokenFailed() async throws {
        try await confirmation { confirm in
            self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
                #expect(self.channel.identifier == channelID)
                confirm()
                return AirshipHTTPResponse(
                    result: nil,
                    statusCode: 400,
                    headers: [:]
                )
            }

            do {
                let _ = try await self.contactManager.resolveAuth(
                    identifier: "some contact id"
                )
                Issue.record("Should throw")
            } catch {}
        }
    }

    @Test("Generate default contact info")
    func generateDefaultContactInfo() async {
        var contactInfo = await self.contactManager.currentContactIDInfo()
        #expect(contactInfo == nil)


        await self.contactManager.generateDefaultContactIDIfNotSet()
        contactInfo = await self.contactManager.currentContactIDInfo()
        #expect(contactInfo != nil)


        #expect(contactInfo!.contactID.lowercased() == contactInfo!.contactID)

        await self.verifyUpdates([
            .contactIDUpdate(
                ContactIDInfo(
                    contactID: contactInfo!.contactID,
                    isStable: true,
                    namedUserID: nil,
                    resolveDate: self.date.now
                )
            )
        ])
    }

    @Test("Generate default contact info lowercased ID")
    func generateDefaultContactInfoLowercasedID() async {
        await self.contactManager.generateDefaultContactIDIfNotSet()
        let contactInfo = await self.contactManager.currentContactIDInfo()
        #expect(contactInfo != nil)
        #expect(contactInfo!.contactID.lowercased() == contactInfo!.contactID)
    }

    @Test("Generate default contact info already set")
    func generateDefaultContactInfoAlreadySet() async throws {
        await self.contactManager.addOperation(.resolve)
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }
        let _ = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )

        let contactInfo = await self.contactManager.currentContactIDInfo()!

        await self.contactManager.generateDefaultContactIDIfNotSet()

        let afterGenerate = await self.contactManager.currentContactIDInfo()
        #expect(contactInfo == afterGenerate)
    }

    @Test("Contact unstable pending reset")
    func contactUnstablePendingReset() async throws {
        await self.contactManager.generateDefaultContactIDIfNotSet()
        let contactInfo = await self.contactManager.currentContactIDInfo()!

        await self.verifyUpdates([
            .contactIDUpdate(
                ContactIDInfo(
                    contactID: contactInfo.contactID,
                    isStable: true,
                    namedUserID: nil,
                    resolveDate: self.date.now
                )
            )
        ])

        await self.contactManager.addOperation(.reset)

        await self.verifyUpdates([
            .contactIDUpdate(
                ContactIDInfo(
                    contactID: contactInfo.contactID,
                    isStable: false,
                    namedUserID: nil,
                    resolveDate: self.date.now
                )
            )
        ])
    }

    @Test("Contact unstable pending identify")
    func contactUnstablePendingIdentify() async throws {
        await self.contactManager.generateDefaultContactIDIfNotSet()
        let contactInfo = await self.contactManager.currentContactIDInfo()!

        await self.verifyUpdates([
            .contactIDUpdate(
                ContactIDInfo(
                    contactID: contactInfo.contactID,
                    isStable: true,
                    namedUserID: nil,
                    resolveDate: self.date.now
                )
            )
        ])

        await self.contactManager.addOperation(.identify("something something"))

        await self.verifyUpdates([
            .contactIDUpdate(
                ContactIDInfo(
                    contactID: contactInfo.contactID,
                    isStable: false,
                    namedUserID: nil,
                    resolveDate: self.date.now
                )
            )
        ])
    }

    @Test("Pending updates combine operations")
    func pendingUpdatesCombineOperations() async throws {
        await self.contactManager.generateDefaultContactIDIfNotSet()

        let tags = [
            TagGroupUpdate(group: "some group", tags: ["tag"], type: .add)
        ]

        let attributes = [
            AttributeUpdate(attribute: "some attribute", type: .set, jsonValue: .string("cool"), date: self.date.now)
        ]

        let subscriptions = [
            ScopedSubscriptionListUpdate(listId: "some list", type: .unsubscribe, scope: .app, date: self.date.now)
        ]

        await self.contactManager.addOperation(
            .update(
                tagUpdates: tags,
                attributeUpdates: nil,
                subscriptionListsUpdates: nil
            )
        )

        await self.contactManager.addOperation(
            .update(
                tagUpdates: nil,
                attributeUpdates: attributes,
                subscriptionListsUpdates: nil
            )
        )

        await self.contactManager.addOperation(
            .update(
                tagUpdates: nil,
                attributeUpdates: nil,
                subscriptionListsUpdates: subscriptions
            )
        )

        let contactID = await self.contactManager.currentContactIDInfo()!.contactID
        let pendingOverrides = await self.contactManager.pendingAudienceOverrides(
            contactID: contactID
        )

        #expect(tags == pendingOverrides.tags)
        #expect(attributes == pendingOverrides.attributes)
        #expect(subscriptions == pendingOverrides.subscriptionLists)
    }

    @Test("Pending updates")
    func pendingUpdates() async throws {
        let tags = [
            TagGroupUpdate(group: "some group", tags: ["tag"], type: .add)
        ]

        let attributes = [
            AttributeUpdate(attribute: "some attribute", type: .set, jsonValue: .string("cool"), date: self.date.now)
        ]

        let subscriptions = [
            ScopedSubscriptionListUpdate(listId: "some list", type: .unsubscribe, scope: .app, date: self.date.now)
        ]

        await self.contactManager.generateDefaultContactIDIfNotSet()
        let contactID = await self.contactManager.currentContactIDInfo()!.contactID

        await self.contactManager.addOperation(
            .update(
                tagUpdates: tags,
                attributeUpdates: nil,
                subscriptionListsUpdates: nil
            )
        )

        await self.contactManager.addOperation(.identify("some user"))
        await self.contactManager.addOperation(
            .update(
                tagUpdates: nil,
                attributeUpdates: attributes,
                subscriptionListsUpdates: nil
            )
        )

        await self.contactManager.addOperation(.identify("some other user"))
        await self.contactManager.addOperation(
            .update(
                tagUpdates: nil,
                attributeUpdates: nil,
                subscriptionListsUpdates: subscriptions
            )
        )


        // Since are an anon user ID, we should get the tags,
        // assume the identify will keep the same contact id,
        // get the attributes, then skip the subscriptions
        // because it will for sure be a different contact ID

        let anonUserOverrides = await self.contactManager.pendingAudienceOverrides(contactID: contactID)
        #expect(tags == anonUserOverrides.tags)
        #expect(attributes == anonUserOverrides.attributes)
        #expect([] == anonUserOverrides.subscriptionLists)


        // If we request a stale contact ID, it should return empty overrides
        let staleOverrides = await self.contactManager.pendingAudienceOverrides(contactID: "not the current contact id")
        #expect([] == staleOverrides.tags)
        #expect([] == staleOverrides.attributes)
        #expect([] == staleOverrides.subscriptionLists)
    }

    @Test("Register email")
    func registerEmail() async throws {
        let expectedAddress = "ua@airship.com"
        let expectedOptions = EmailRegistrationOptions.options(
            transactionalOptedIn: Date(),
            properties: ["interests": "newsletter"],
            doubleOptIn: true
        )

        await self.contactManager.addOperation(
            .registerEmail(address: expectedAddress, options: expectedOptions)
        )

        // Should resolve contact first
        let resolveExpectation = expectation(description: "resolve")
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            resolveExpectation.fulfill()
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        // Then register the channel
        try await confirmation { confirm in
            self.apiClient.registerEmailCallback = { contactID, address, options, locale in
                #expect(contactID == self.anonIdentifyResponse.contact.contactID)
                #expect(address == expectedAddress)
                #expect(options == options)
                #expect(locale == self.localeManager.currentLocale)
                confirm()
                return AirshipHTTPResponse(
                    result: .init(channelType: .email, channelID: "some channel"),
                    statusCode: 200,
                    headers: [:]
                )
            }

            let result = try await self.workManager.launchTask(
                request: AirshipWorkRequest(
                    workID: ContactManager.updateTaskID
                )
            )
            #expect(result == .success)
        }

        await resolveExpectation.fulfillment
    }

    @Test("Register open")
    func registerOpen() async throws {
        let expectedAddress = "ua@airship.com"
        let expectedOptions = OpenRegistrationOptions.optIn(
            platformName: "my_platform",
            identifiers: ["model": "4"]
        )

        await self.contactManager.addOperation(
            .registerOpen(address: expectedAddress, options: expectedOptions)
        )

        // Should resolve contact first
        let resolveExpectation = expectation(description: "resolve")
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            resolveExpectation.fulfill()
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        // Then register the channel
        try await confirmation { confirm in
            self.apiClient.registerOpenCallback = { contactID, address, options, locale in
                #expect(contactID == self.anonIdentifyResponse.contact.contactID)
                #expect(address == expectedAddress)
                #expect(options == options)
                #expect(locale == self.localeManager.currentLocale)
                confirm()
                return AirshipHTTPResponse(
                    result: .init(channelType: .open, channelID: "some channel"),
                    statusCode: 200,
                    headers: [:]
                )
            }

            let result = try await self.workManager.launchTask(
                request: AirshipWorkRequest(
                    workID: ContactManager.updateTaskID
                )
            )
            #expect(result == .success)
        }

        await resolveExpectation.fulfillment
    }

    @Test("Register SMS")
    func registerSMS() async throws {
        let expectedAddress = "15035556789"
        let expectedOptions = SMSRegistrationOptions.optIn(senderID: "28855")

        await self.contactManager.addOperation(
            .registerSMS(msisdn: expectedAddress, options: expectedOptions)
        )

        // Should resolve contact first
        let resolveExpectation = expectation(description: "resolve")
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            resolveExpectation.fulfill()
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        // Then register the channel
        try await confirmation { confirm in
            self.apiClient.registerSMSCallback = {contactID, address, options, locale in
                #expect(address == expectedAddress)
                #expect(options == options)
                #expect(locale == self.localeManager.currentLocale)
                confirm()
                return AirshipHTTPResponse(
                    result: .init(channelType: .sms, channelID: "some channel"),
                    statusCode: 200,
                    headers: [:]
                )
            }

            let result = try await self.workManager.launchTask(
                request: AirshipWorkRequest(
                    workID: ContactManager.updateTaskID
                )
            )
            #expect(result == .success)
        }

        await resolveExpectation.fulfillment
    }

    @Test("Resend email")
    func resendEmail() async throws {
        let expectedAddress: String = "example@email.com"

        let expectedResendOptions = ResendOptions(emailAddress: expectedAddress)

        // Should resolve contact first after checking the token
        let resolveExpectation = expectation(description: "resolve")
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            resolveExpectation.fulfill()
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        let pendingChannel = makePendingEmailContactChannel(address: expectedAddress)

        await self.contactManager.addOperation(
            .resend(channel: pendingChannel)
        )

        try await confirmation { confirm in
            self.apiClient.resendCallback = { resendOptions in
                #expect(resendOptions == expectedResendOptions)
                confirm()
                return AirshipHTTPResponse(
                    result: true,
                    statusCode: 200,
                    headers: [:]
                )
            }

            let result = try await self.workManager.launchTask(
                request: AirshipWorkRequest(
                    workID: ContactManager.updateTaskID
                )
            )

            #expect(result == .success)
        }

        await resolveExpectation.fulfillment
    }

    @Test("Resend SMS")
    func resendSMS() async throws {
        let expectedMSISDN: String = "12345"
        let expectedSenderID: String = "1111"

        let expectedResendOptions = ResendOptions(msisdn: expectedMSISDN, senderID: expectedSenderID)

        // Should resolve contact first after checking the token
        let resolveExpectation = expectation(description: "resolve")
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            resolveExpectation.fulfill()
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        let pendingChannel = makePendingSMSContactChannel(msisdn: expectedMSISDN, sender: expectedSenderID)

        await self.contactManager.addOperation(
            .resend(channel: pendingChannel)
        )

        try await confirmation { confirm in
            self.apiClient.resendCallback = { resendOptions in
                #expect(resendOptions == expectedResendOptions)
                confirm()
                return AirshipHTTPResponse(
                    result: true,
                    statusCode: 200,
                    headers: [:]
                )
            }

            let result = try await self.workManager.launchTask(
                request: AirshipWorkRequest(
                    workID: ContactManager.updateTaskID
                )
            )

            #expect(result == .success)
        }

        await resolveExpectation.fulfillment
    }

    @Test("Resend channel")
    func resendChannel() async throws {
        let expectedChannelID = "12345"
        let expectedChannelType: ChannelType = ChannelType.email

        let expectedResendOptions = ResendOptions(channelID: expectedChannelID, channelType: expectedChannelType)

        // Should resolve contact first after checking the token
        let resolveExpectation = expectation(description: "resolve")
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            resolveExpectation.fulfill()
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        let registeredChannel = makeRegisteredContactChannel(from: expectedChannelID)

        await self.contactManager.addOperation(
            .resend(channel: registeredChannel)
        )

        try await confirmation { confirm in
            self.apiClient.resendCallback = { resendOptions in
                #expect(resendOptions == expectedResendOptions)
                confirm()
                return AirshipHTTPResponse(
                    result: true,
                    statusCode: 200,
                    headers: [:]
                )
            }

            let result = try await self.workManager.launchTask(
                request: AirshipWorkRequest(
                    workID: ContactManager.updateTaskID
                )
            )

            #expect(result == .success)
        }

        await resolveExpectation.fulfillment
    }

    @Test("Disassociate")
    func disassociate() async throws {
        let expectedChannelID = "12345"
        let registeredChannel = makeRegisteredContactChannel(from: expectedChannelID)

        await self.contactManager.addOperation(
            .disassociateChannel(channel: registeredChannel)
        )

        // Should resolve contact first
        let resolveExpectation = expectation(description: "resolve")
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            resolveExpectation.fulfill()
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        // Then disassociate the channel
        try await confirmation { confirm in
            self.apiClient.disassociateChannelCallback = { contactID, channelID, type in
                #expect(channelID == expectedChannelID)
                #expect(type == ChannelType.email)
                confirm()
                return AirshipHTTPResponse(
                    result: ContactDisassociateChannelResult(channelID: channelID),
                    statusCode: 200,
                    headers: [:]
                )
            }

            let result = try await self.workManager.launchTask(
                request: AirshipWorkRequest(
                    workID: ContactManager.updateTaskID
                )
            )
            #expect(result == .success)
        }

        await resolveExpectation.fulfillment
    }

    @Test("Associate channel")
    func associateChannel() async throws {
        await self.contactManager.addOperation(
            .associateChannel(
                channelID: "some channel",
                channelType: .open
            )
        )

        // Should resolve contact first
        let resolveExpectation = expectation(description: "resolve")
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            resolveExpectation.fulfill()
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        // Then register the channel
        try await confirmation { confirm in
            self.apiClient.associateChannelCallback = { contactID, channelID, type in
                #expect(contactID == "some contact")
                #expect(channelID == "some channel")
                #expect(type == .open)
                confirm()
                return AirshipHTTPResponse(
                    result: .init(channelType: type, channelID: "some channel"),
                    statusCode: 200,
                    headers: [:]
                )
            }

            let result = try await self.workManager.launchTask(
                request: AirshipWorkRequest(
                    workID: ContactManager.updateTaskID
                )
            )
            #expect(result == .success)
        }

        await resolveExpectation.fulfillment
    }

    @Test("Update")
    func update() async throws {
        let tags = [
            TagGroupUpdate(group: "some group", tags: ["tag"], type: .add),
            TagGroupUpdate(group: "some group", tags: ["tag"], type: .remove),
            TagGroupUpdate(group: "some group", tags: ["some other tag"], type: .remove)
        ]

        let attributes = [
            AttributeUpdate(attribute: "some other attribute", type: .set, jsonValue: .string("cool"), date: self.date.now),
            AttributeUpdate(attribute: "some attribute", type: .set, jsonValue: .string("cool"), date: self.date.now),
            AttributeUpdate(attribute: "some attribute", type: .remove, jsonValue: .string("cool"), date: self.date.now)
        ]

        let subscriptions = [
            ScopedSubscriptionListUpdate(listId: "some other list", type: .subscribe, scope: .app, date: self.date.now),
            ScopedSubscriptionListUpdate(listId: "some list", type: .unsubscribe, scope: .app, date: self.date.now),
            ScopedSubscriptionListUpdate(listId: "some list", type: .subscribe, scope: .app, date: self.date.now)
        ]

        await self.contactManager.addOperation(
            .update(
                tagUpdates: tags,
                attributeUpdates: attributes,
                subscriptionListsUpdates: subscriptions
            )
        )

        // Should resolve contact first
        let resolveExpectation = expectation(description: "resolve")
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            resolveExpectation.fulfill()
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        // Then register the channel
        let updateExpectation = expectation(description: "update")
        self.apiClient.updateCallback = { contactID, tagUpdates, attributeUpdates, subscriptionUpdates in
            #expect(contactID == self.anonIdentifyResponse.contact.contactID)
            #expect(tagUpdates == AudienceUtils.collapse(tags))
            #expect(attributeUpdates == AudienceUtils.collapse(attributes))
            #expect(subscriptionUpdates == AudienceUtils.collapse(subscriptions))
            updateExpectation.fulfill()
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 200,
                headers: [:]
            )
        }

        let audienceCallbackExpectation = expectation(description: "audience callback")
        await self.contactManager.onAudienceUpdated { update in
            #expect(update.tags == AudienceUtils.collapse(tags))
            #expect(update.attributes == AudienceUtils.collapse(attributes))
            #expect(update.subscriptionLists == AudienceUtils.collapse(subscriptions))
            audienceCallbackExpectation.fulfill()
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )
        #expect(result == .success)

        await resolveExpectation.fulfillment
        await updateExpectation.fulfillment
        await audienceCallbackExpectation.fulfillment
    }

    @Test("Conflict")
    func conflict() async throws {
        let tags = [
            TagGroupUpdate(group: "some group", tags: ["tag"], type: .add),
        ]

        let attributes = [
            AttributeUpdate(attribute: "some attribute", type: .set, jsonValue: .string("cool"), date: self.date.now),
        ]

        let subscriptions = [
            ScopedSubscriptionListUpdate(listId: "some list", type: .subscribe, scope: .app, date: self.date.now),
        ]

        // Adds some anon data
        await self.contactManager.addOperation(
            .update(
                tagUpdates: tags,
                attributeUpdates: attributes,
                subscriptionListsUpdates: subscriptions
            )
        )

        // resolve
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        // update
        self.apiClient.updateCallback = { contactID, tagUpdates, attributeUpdates, subscriptionUpdates in
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 200,
                headers: [:]
            )
        }

        // identify
        self.apiClient.identifyCallback = { channelID, namedUserID, contactID, possiblyOrphanedContactID in
            return AirshipHTTPResponse(
                result: self.nonAnonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        var result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )

        await self.contactManager.addOperation(.identify("some named user"))

        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )
        #expect(result == .success)


        let expctedConflictEvent =  ContactConflictEvent(
            tags: ["some group": ["tag"]],
            attributes: ["some attribute": .string("cool")],
            associatedChannels: [],
            subscriptionLists: ["some list": [.app]],
            conflictingNamedUserID: "some named user"
        )
        // resolve, update, resolve, conflict
        let conflict = await self.collectUpdates(count: 4).last
        #expect(conflict == .conflict(expctedConflictEvent))
    }

    private func collectUpdates(count: Int) async -> [ContactUpdate] {
        guard count > 0 else { return [] }

        var collected: [ContactUpdate] = []
        for await contactUpdate in await self.contactManager.contactUpdates {
            collected.append(contactUpdate)
            if (collected.count == count) {
                break
            }
        }

        return collected
    }


    private func makePendingEmailContactChannel(address: String) -> ContactChannel {
        return .email(
            .pending(
                ContactChannel.Email.Pending(
                    address: address,
                    registrationOptions: .options(properties: nil, doubleOptIn: true)
                )
            )
        )
    }

    private func makePendingSMSContactChannel(msisdn: String, sender: String) -> ContactChannel {
        return .sms(
            .pending(
                ContactChannel.Sms.Pending(
                    address: msisdn,
                    registrationOptions: .optIn(senderID: sender)
                )
            )
        )
    }

    private func makeRegisteredContactChannel(from channelID: String) -> ContactChannel {
        return .email(
            .registered(
                ContactChannel.Email.Registered(
                    channelID: channelID,
                    maskedAddress: "****@email.com"
                )
            )
        )
    }

    private func verifyUpdates(_ expected: [ContactUpdate], sourceLocation: SourceLocation = #_sourceLocation) async {
        let collected = await self.collectUpdates(count: expected.count)
        #expect(collected == expected, sourceLocation: sourceLocation)
    }

    private func expectation(description: String, expectedFulfillmentCount: Int = 1) -> Expectation {
        return Expectation(description: description, expectedFulfillmentCount: expectedFulfillmentCount)
    }
}

actor Expectation {
    private var count: Int = 0
    private let expectedCount: Int
    private let description: String

    init(description: String, expectedFulfillmentCount: Int = 1) {
        self.description = description
        self.expectedCount = expectedFulfillmentCount
    }

    nonisolated func fulfill() {
        Task {
            await self.incrementCount()
        }
    }

    private func incrementCount() {
        count += 1
    }

    var fulfillment: Void {
        get async {
            while count < expectedCount {
                await Task.yield()
            }
        }
    }
}
