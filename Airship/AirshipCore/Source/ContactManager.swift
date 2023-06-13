import Foundation

actor ContactManager: ContactManagerProtocol {

    private static let operationsKey = "Contact.operationEntries"
    private static let legacyOperationsKey = "Contact.operations" // operations without the date
    private static let contactInfoKey = "Contact.contactInfo"
    private static let anonContactDataKey = "Contact.anonContactData"

    static let identityRateLimitID = "Contact.identityRateLimitID"
    static let updateRateLimitID = "Contact.updateRateLimitID"
    static let updateTaskID = "Contact.update"
    
    private let cachedAuthToken: CachedValue<AuthToken> = CachedValue()
    private var dataStore: PreferenceDataStore
    private let identifySerialQueue: SerialQueue = SerialQueue()
    private let channel: AirshipChannelProtocol
    private let apiClient: ContactsAPIClientProtocol
    private let workManager: AirshipWorkManagerProtocol
    private let date: AirshipDateProtocol
    private let internalIdentifyRateLimit: TimeInterval

    private let localeManager: AirshipLocaleManagerProtocol
    private var onAudienceUpdatedCallback: ((ContactAudienceUpdate) async -> Void)?
    private var lastContactIDUpdate: ContactIDInfo?
    private var lastNamedUserUpdate: String?

    let contactUpdates: AsyncStream<ContactUpdate>
    private let contactUpdatesContinuation: AsyncStream<ContactUpdate>.Continuation

    private var isEnabled: Bool = false
    
    private var lastIdentifyOperation = Date.distantPast

    private var operationEntries: [ContactOperationEntry] {
        get {
            if (dataStore.keyExists(ContactManager.operationsKey)) {
                return dataStore.safeCodable(forKey: ContactManager.operationsKey) ?? []
            } else if (dataStore.keyExists(ContactManager.legacyOperationsKey)) {
                let operations: [ContactOperation] = dataStore.safeCodable(forKey: ContactManager.operationsKey) ?? []
                let now = date.now
                let entries = operations.map { operation in
                    return ContactOperationEntry(date: now, operation: operation, identifier: UUID().uuidString)
                }

                dataStore.setSafeCodable(entries, forKey: ContactManager.operationsKey)
                dataStore.removeObject(forKey: ContactManager.legacyOperationsKey)
                return entries
            }
            return []
        }
        set {
            dataStore.setSafeCodable(newValue, forKey: ContactManager.operationsKey)
        }
    }

    private var anonData: AnonContactData? {
        get {
            return dataStore.safeCodable(forKey: ContactManager.anonContactDataKey)
        }
        set {
            dataStore.setSafeCodable(newValue, forKey: ContactManager.anonContactDataKey)
        }
    }

    private var lastContactInfo: InternalContactInfo?  {
        get {
            return dataStore.safeCodable(forKey: ContactManager.contactInfoKey)
        }
        set {
            dataStore.setSafeCodable(newValue, forKey: ContactManager.contactInfoKey)
        }
    }
    
    private var possiblyOrphanedContactID: String? {
           guard let lastContactInfo = self.lastContactInfo,
                 lastContactInfo.isAnonymous,
                 (anonData?.channels.isEmpty ?? true)
           else {
               return nil
           }

           return lastContactInfo.contactID
    }

    init(
        dataStore: PreferenceDataStore,
        channel: AirshipChannelProtocol,
        localeManager: AirshipLocaleManagerProtocol,
        apiClient: ContactsAPIClientProtocol,
        date: AirshipDateProtocol = AirshipDate.shared,
        workManager: AirshipWorkManagerProtocol = AirshipWorkManager.shared,
        internalIdentifyRateLimit: TimeInterval = 5.0
    ) {
        self.dataStore = dataStore
        self.apiClient = apiClient
        self.channel = channel
        self.date = date
        self.workManager = workManager
        self.localeManager = localeManager
        self.internalIdentifyRateLimit = internalIdentifyRateLimit

        (
            self.contactUpdates,
            self.contactUpdatesContinuation
        ) = AsyncStream<ContactUpdate>.makeStreamWithContinuation()

        self.workManager.registerWorker(
            ContactManager.updateTaskID,
            type: .serial
        ) { [weak self] _ in
            if (try await self?.perfromNextOperation() != false) {
                return .success
            }
            return .failure
        }

        workManager.setRateLimit(
            ContactManager.identityRateLimitID,
            rate: 1,
            timeInterval: 5.0
        )

        workManager.setRateLimit(
            ContactManager.updateRateLimitID,
            rate: 1,
            timeInterval: 0.5
        )

        Task {
            await self.yieldContactUpdates()
        }
    }

    func onAudienceUpdated(onAudienceUpdatedCallback: (@Sendable (ContactAudienceUpdate) async -> Void)?) {
        self.onAudienceUpdatedCallback = onAudienceUpdatedCallback
    }

    func addOperation(_ operation: ContactOperation) {
        self.operationEntries.append(
            ContactOperationEntry(date: self.date.now, operation: operation, identifier: UUID().uuidString)
        )

        self.yieldContactUpdates()
        self.enqueueTask()
    }

    func generateDefaultContactIDIfNotSet() -> Void {
        guard self.lastContactInfo == nil else {
            return
        }

        self.lastContactInfo = InternalContactInfo(
            contactID: UUID().uuidString,
            isAnonymous: true,
            namedUserID: nil,
            channelAssociatedDate: self.date.now
        )

        self.yieldContactUpdates()
    }

    func currentNamedUserID() -> String? {
        let entries = self.operationEntries.reversed().first { entry in
            entry.operation.type == .identify || entry.operation.type == .reset
        }

        if let entry = entries {
            switch(entry.operation) {
            case .reset:
                return nil
            case .identify(let identifier):
                return identifier
            default: break
            }
        }

        return self.lastContactInfo?.namedUserID
    }

    func resolveAuth(identifier: String) async throws -> String {
        if lastContactInfo?.contactID == identifier, let token = tokenIfValid() {
            return token
        }

        _ = try await performOperation(.resolve)
        self.yieldContactUpdates()

        guard lastContactInfo?.contactID == identifier else {
            throw AirshipErrors.error("Mismatch contact ID")
        }

        if let token = tokenIfValid() {
            return token
        }

        throw AirshipErrors.error("Failed to refresh token")
    }

    func authTokenExpired(token: String) async {
        self.cachedAuthToken.expireIf { auth in
            return auth.token == token
        }
    }

    func setEnabled(enabled: Bool) {
        guard self.isEnabled != enabled else  { return }
        self.isEnabled = enabled

        if enabled {
            enqueueTask()
        }
    }

    func currentContactIDInfo() -> ContactIDInfo? {
        guard let lastContactInfo = self.lastContactInfo else {
            return nil
        }

        return ContactIDInfo(
            contactID: lastContactInfo.contactID,
            isStable: self.isContactIDStable()
        )
    }

    // Worker -> one at a time
    private func perfromNextOperation() async throws -> Bool {
        guard self.isEnabled else { return true }

        guard !self.operationEntries.isEmpty else {
            return true
        }

        defer {
            self.yieldContactUpdates()
        }

        // Make sure we have a valid token so we know we are operating on
        // the correct contact ID to hopefully avoid any error logs if the
        // contact ID changes in the middle of an update
        if  tokenIfValid() == nil  {
            let resolveResult = try await performOperation(.resolve)
            self.yieldContactUpdates()
            if (!resolveResult) {
                return false
            }
        }

        self.clearSkippableOperations()
        yieldContactUpdates()

        guard let operationGroup = prepareNextOperationGroup() else {
            return true
        }

        let result = try await performOperation(operationGroup.mergedOperation)
        if (result) {
            let identifiers = operationGroup.operations.map { $0.identifier }

            self.operationEntries.removeAll { entry in
                identifiers.contains(entry.identifier)
            }

            if (!self.operationEntries.isEmpty) {
                self.enqueueTask()
            }
        }

        return result
    }

    private func tokenIfValid() -> String? {
        if let token = self.cachedAuthToken.value,
           token.identifier == self.lastContactInfo?.contactID,
           self.cachedAuthToken.timeRemaining >= 30
        {
            return token.token
        }

        return nil
    }

    private func enqueueTask() {
        guard
            self.channel.identifier != nil,
            self.isEnabled
        else {
            return
        }

        var rateLimitIDs = [ContactManager.updateRateLimitID]

        let next = self.operationEntries.first { !self.isSkippable(operation: $0.operation) }?.operation
        if (next?.type == .reset || next?.type == .identify || tokenIfValid() == nil) {
            rateLimitIDs += [ContactManager.identityRateLimitID]
        }

        self.workManager.dispatchWorkRequest(
            AirshipWorkRequest(
                workID: ContactManager.updateTaskID,
                requiresNetwork: true,
                rateLimitIDs: rateLimitIDs
            )
        )
    }

    private func clearSkippableOperations() {
        var operations = self.operationEntries
        while let next = operations.first {
            if (isSkippable(operation: next.operation)) {
                operations.removeFirst()
            } else {
                break
            }
        }
        self.operationEntries = operations
    }

    private func performOperation(_ operation: ContactOperation) async throws -> Bool {
        guard !self.isSkippable(operation: operation) else {
            return true
        }

        switch operation {
        case .update(let tagUpdates, let attributeUpdates, let subListUpdates):
            return try await performUpdateOperation(
                tagGroupUpdates: tagUpdates,
                attributeUpdates: attributeUpdates,
                subscriptionListsUpdates: subListUpdates
            )

        case .identify(let identifier):
            return try await doIdentify {
                return try await self.performIdentifyOperation(
                    identifier: identifier
                )
            }

        case .reset:
            return try await doIdentify {
                return try await self.performResetOperation()
            }

        case .resolve:
            return try await doIdentify {
                return try await self.performResolveOperation()
            }

        case .registerEmail(let address, let options):
            return try await performRegisterEmailOperation(
                address: address,
                options: options
            )

        case .registerSMS(let msisdn, let options):
            return try await performRegisterSMSOperation(
                msisdn: msisdn,
                options: options
            )

        case .registerOpen(let address, let options):
            return try await performRegisterOpenChannelOperation(
                address: address,
                options: options
            )

        case .associateChannel(let channelID, let type):
            return try await performAssociateChannelOperation(
                channelID: channelID,
                type: type
            )
        }
    }

    private func performResolveOperation() async throws -> Bool {
        let response = try await self.apiClient.resolve(
            channelID: try requireChannelID(),
            contactID: nil,
            possiblyOrphanedContactID: possiblyOrphanedContactID
        )

        if let result = response.result, response.isSuccess{
            await updateContactInfo(result: result, operationType: .resolve)
        }

        return response.isOperationComplete
    }

    private func performResetOperation() async throws -> Bool {
        let response = try await self.apiClient.reset(
            channelID: try requireChannelID(),
            possiblyOrphanedContactID: possiblyOrphanedContactID
        )

        if let result = response.result, response.isSuccess {
            await updateContactInfo(result: result, operationType: .resolve)
        }

        return response.isOperationComplete
    }

    private func performIdentifyOperation(identifier: String) async throws -> Bool {
        let response = try await self.apiClient.identify(
            channelID: try requireChannelID(),
            namedUserID: identifier,
            contactID: self.lastContactInfo?.contactID,
            possiblyOrphanedContactID: possiblyOrphanedContactID
        )

        if let result = response.result, response.isSuccess {
            await updateContactInfo(
                result: result,
                namedUserID: identifier,
                operationType: .resolve
            )
        }

        return response.isOperationComplete
    }

    private func performRegisterEmailOperation(
        address: String,
        options: EmailRegistrationOptions
    ) async throws -> Bool {
        let result = try await self.apiClient.registerEmail(
            contactID: try requireContactID(),
            address: address,
            options: options,
            locale: self.localeManager.currentLocale
        )

        return result.isOperationComplete
    }

    private func performRegisterSMSOperation(msisdn: String, options: SMSRegistrationOptions) async throws -> Bool {
        let result = try await self.apiClient.registerSMS(
            contactID: try requireContactID(),
            msisdn: msisdn,
            options: options,
            locale: self.localeManager.currentLocale
        )

        return result.isOperationComplete
    }

    private func performRegisterOpenChannelOperation(address: String, options: OpenRegistrationOptions) async throws -> Bool {
        let result = try await self.apiClient.registerOpen(
            contactID: try requireContactID(),
            address: address,
            options: options,
            locale: self.localeManager.currentLocale
        )

        return result.isOperationComplete
    }

    private func performAssociateChannelOperation(channelID: String, type: ChannelType) async throws -> Bool {
        let result = try await self.apiClient.associateChannel(
            contactID: try requireContactID(),
            channelID: channelID,
            channelType: type
        )

        return result.isOperationComplete
    }

    private func performUpdateOperation(
        tagGroupUpdates: [TagGroupUpdate]?,
        attributeUpdates: [AttributeUpdate]?,
        subscriptionListsUpdates: [ScopedSubscriptionListUpdate]?
    ) async throws -> Bool {
        guard let contactInfo = self.lastContactInfo else {
            AirshipLogger.error("Failed to update contact, missing contact ID.")
            return false
        }

        let response = try await self.apiClient.update(
            contactID: contactInfo.contactID,
            tagGroupUpdates: tagGroupUpdates,
            attributeUpdates: attributeUpdates,
            subscriptionListUpdates: subscriptionListsUpdates
        )

        if response.isSuccess {
            await self.contactUpdated(
                contactID: contactInfo.contactID,
                tagGroupUpdates: tagGroupUpdates,
                attributeUpdates: attributeUpdates,
                subscriptionListsUpdates: subscriptionListsUpdates
            )
        }

        return response.isOperationComplete
    }

    func pendingAudienceOverrides(contactID: String) -> ContactAudienceOverrides {
        // If we have a contact ID but its stale, return an empty overrides
        guard contactID == self.lastContactInfo?.contactID else {
            return ContactAudienceOverrides()
        }

        var tags: [TagGroupUpdate] = []
        var attributes: [AttributeUpdate] = []
        var subscriptionLists: [ScopedSubscriptionListUpdate] = []
        let operations = operationEntries.map { $0.operation }

        var lastOperationNamedUser: String? = nil

        for operation in operations {
            // A reset will generate a new contact ID
            if case .reset = operation {
               break
            }

            if case let .identify(namedUserID) = operation {
                // If we come across an identify operation that does not match the current contact info,
                // then any further operations are for a different contact
                if self.lastContactInfo?.isAnonymous == false, namedUserID != self.lastContactInfo?.namedUserID {
                    break
                }

                // If we have a lastOperationNamedUser and it does not match the operation
                if lastOperationNamedUser != nil, lastOperationNamedUser != namedUserID {
                    break
                }

                lastOperationNamedUser = namedUserID
                continue
            }

            if case let .update(tagUpdates, attributesUpdates, subscriptionListsUpdates) = operation {
                if let tagUpdates = tagUpdates {
                    tags += tagUpdates
                }
                if let attributesUpdates = attributesUpdates {
                    attributes += attributesUpdates
                }
                if let subscriptionListsUpdates = subscriptionListsUpdates {
                    subscriptionLists += subscriptionListsUpdates
                }

                continue
            }
        }

        return ContactAudienceOverrides(
            tags: tags,
            attributes: attributes,
            subscriptionLists: subscriptionLists
        )
    }

    private func hasAnonData() -> Bool {
        guard self.lastContactInfo?.isAnonymous == true,
              let anonData = self.anonData else {
            return false
        }
        return !anonData.isEmpty
    }

    private func requireContactID() throws -> String {
        guard let contactID = lastContactInfo?.contactID else {
            throw AirshipErrors.error("Missing contact ID")
        }
        return contactID
    }

    private func requireChannelID() throws -> String {
        guard let channelID = self.channel.identifier else {
            throw AirshipErrors.error("Missing channel ID")
        }
        return channelID
    }
    
    private func prepareNextOperationGroup() -> ContactOperationGroup? {
        var operations = self.operationEntries

        guard let next = operations.first else {
            return nil
        }

        operations.removeFirst()


        switch (next.operation) {
        case .update(let nextTags, let nextAttributes, let nextSubList):
            // Group updates into a single update

            var group = [next]
            var mergedTags = nextTags ?? []
            var mergedAttributes = nextAttributes ?? []
            var mergedSubLists = nextSubList ?? []

            for nextNext in operations {
                if case let .update(otherTags, otherAttributes, otherSubLists) = nextNext.operation {
                    mergedTags += (otherTags ?? [])
                    mergedAttributes += (otherAttributes ?? [])
                    mergedSubLists += (otherSubLists ?? [])
                    group.append(nextNext)
                } else {
                    break
                }
            }

            let mergedUpdate: ContactOperation = .update(
                tagUpdates: AudienceUtils.collapse(mergedTags),
                attributeUpdates: AudienceUtils.collapse(mergedAttributes),
                subscriptionListsUpdates: AudienceUtils.collapse(mergedSubLists)
            )

            return ContactOperationGroup(
                operations: group,
                mergedOperation: mergedUpdate
            )

        case .identify(_): fallthrough
        case .reset:
            // A series of resets and identifies can be skipped and only the last reset or identify
            // can be performed if we do not have any anon data.

            guard !hasAnonData() else {
                return ContactOperationGroup(
                    operations: [next],
                    mergedOperation: next.operation
                )
            }

            var group = [next]
            var last = next
            for nextNext in operations {
                if (nextNext.operation.type == .identify || nextNext.operation.type == .reset) {
                    group.append(nextNext)
                    last = nextNext
                } else {
                    break
                }
            }

            return ContactOperationGroup(
                operations: group,
                mergedOperation: last.operation
            )

        default:
            return ContactOperationGroup(
                operations: [next],
                mergedOperation: next.operation
            )
        }
    }

    private func isContactIDStable() -> Bool {
        guard let lastContactInfo = lastContactInfo else {
            return false
        }

        return !self.operationEntries.contains { entry in
            switch entry.operation {
            case .reset: return true
            case .identify(let identifier):
                if lastContactInfo.namedUserID != identifier {
                    return true
                } else {
                    return false
                }
            default: return false
            }
        }
    }

    private func isSkippable(operation: ContactOperation) -> Bool {
        switch operation {
        case .update(let tagUpdates, let attributeUpdates, let subListUpdates):
            // Skip if its an empty update
            return tagUpdates?.isEmpty ?? true &&
            attributeUpdates?.isEmpty ?? true &&
            subListUpdates?.isEmpty ?? true

        case .identify(let identifier):
            // Skip if we are already this user and have a valid token
            return self.lastContactInfo?.namedUserID == identifier && tokenIfValid() != nil

        case .reset:
            // Skip if we are already anonymous, have no data, and a valid token.
            return lastContactInfo?.isAnonymous == true &&
            self.anonData?.isEmpty != false &&
            tokenIfValid() != nil

        case .resolve:
            // Skip if we have a valid token for the current contact info
            return tokenIfValid() != nil

        default: return false
        }
    }

    private func updateContactInfo(
        result: ContactIdentifyResult,
        namedUserID: String? = nil,
        operationType: ContactOperation.OperationType
    ) async {
        let expiration = self.date.now.addingTimeInterval(
            Double(result.tokenExpiresInMilliseconds)/1000.0
        )

        // Update token
        self.cachedAuthToken.set(
            value: AuthToken(
                identifier: result.contact.contactID,
                token: result.token,
                expiration: expiration
            ),
            expiration: expiration
        )

        var resolvedNamedUser = namedUserID
        if resolvedNamedUser == nil, lastContactInfo?.contactID == result.contact.contactID {
            resolvedNamedUser = lastContactInfo?.namedUserID
        }

        let newContactInfo = InternalContactInfo(
            contactID: result.contact.contactID,
            isAnonymous: result.contact.isAnonymous,
            namedUserID: resolvedNamedUser,
            channelAssociatedDate: result.contact.channelAssociatedDate
        )

        // Conflict events
        if newContactInfo.contactID != self.lastContactInfo?.contactID,
           self.lastContactInfo?.isAnonymous == true,
           let anonData = self.anonData,
           !anonData.isEmpty
        {
            self.contactUpdatesContinuation.yield(
                .conflict(
                    ContactConflictEvent(
                        tags: anonData.tags,
                        attributes: anonData.attributes,
                        channels: anonData.channels,
                        subscriptionLists: anonData.subscriptionLists,
                        conflictingNamedUserID: namedUserID
                    )
                )
            )
            self.anonData = nil
        }

        // Reset anon data
        if !newContactInfo.isAnonymous {
            self.anonData = nil
        }

        // If we have a resolve that returns a new contactID then it means
        // it was changed server side. Clear any pending operations that are
        // older than the resolve date.
        if self.lastContactInfo != nil,
           lastContactInfo?.contactID != newContactInfo.contactID,
           operationType == .resolve {

            self.operationEntries = self.operationEntries.filter { entry in
                result.contact.channelAssociatedDate < entry.date
            }
        }

        self.lastContactInfo = newContactInfo
    }

    private func updateLastIdentifyOperationDate() {
        self.lastIdentifyOperation = self.date.now
    }

    private func yieldContactUpdates() {
        let currentContactIDInfo = self.currentContactIDInfo()
        if let currentContactIDInfo = currentContactIDInfo, currentContactIDInfo != self.lastContactIDUpdate {
            self.contactUpdatesContinuation.yield(.contactIDUpdate(currentContactIDInfo))
            self.lastContactIDUpdate = currentContactIDInfo
        }

        let currentNamedUserID = self.currentNamedUserID()
        if currentNamedUserID != self.lastNamedUserUpdate {
            self.contactUpdatesContinuation.yield(.namedUserUpdate(currentNamedUserID))
            self.lastNamedUserUpdate = currentNamedUserID
        }
    }

    private func doIdentify<T: Sendable>(work: @escaping @Sendable () async throws -> T) async throws -> T {
        try await self.identifySerialQueue.run {
            // We handle identify rate limit internally since both work and auth token might cause identify to be called
            let remainingTime = self.internalIdentifyRateLimit - self.date.now.timeIntervalSince(
                await self.lastIdentifyOperation
            )

            if (remainingTime > 0) {
                try await Task.sleep(
                    nanoseconds: UInt64(remainingTime * 1_000_000_000)
                )
            }

            let result: T = try await work()
            await self.updateLastIdentifyOperationDate()
            return result
        }
    }

    private func contactUpdated(
        contactID: String,
        tagGroupUpdates: [TagGroupUpdate]? = nil,
        attributeUpdates: [AttributeUpdate]? = nil,
        subscriptionListsUpdates: [ScopedSubscriptionListUpdate]? = nil,
        channel: AssociatedChannel? = nil
    ) async {

        guard let contactInfo = self.lastContactInfo,
              contactInfo.contactID == contactID else {
            return
        }

        if tagGroupUpdates?.isEmpty == false || attributeUpdates?.isEmpty == false || subscriptionListsUpdates?.isEmpty == false {
           await self.onAudienceUpdatedCallback?(
                ContactAudienceUpdate(
                    contactID: contactID,
                    tags: tagGroupUpdates,
                    attributes: attributeUpdates,
                    subscriptionLists: subscriptionListsUpdates
                )
            )
        }

        if contactInfo.isAnonymous {
            let data = self.anonData
            var tags = data?.tags ?? [:]
            var attributes = data?.attributes ?? [:]
            var channels = data?.channels ?? []
            var subscriptionLists = data?.subscriptionLists ?? [:]

            tags = AudienceUtils.applyTagUpdates(
                data?.tags,
                updates: tagGroupUpdates
            )

            attributes = AudienceUtils.applyAttributeUpdates(
                data?.attributes,
                updates: attributeUpdates
            )

            subscriptionLists = AudienceUtils.applySubscriptionListsUpdates(
                data?.subscriptionLists,
                updates: subscriptionListsUpdates
            )

            if let channel = channel {
                channels.append(channel)
            }

            self.anonData = AnonContactData(
                tags: tags,
                attributes: attributes,
                channels: channels,
                subscriptionLists: subscriptionLists
            )
        }
    }
}


fileprivate struct InternalContactInfo: Codable, Equatable {
    let contactID: String
    let isAnonymous: Bool
    let namedUserID: String?
    let channelAssociatedDate: Date?
}

fileprivate struct ContactOperationGroup {
    let operations: [ContactOperationEntry]
    let mergedOperation: ContactOperation
}

fileprivate struct ContactOperationEntry: Codable, Sendable {
    let date: Date
    let operation: ContactOperation
    let identifier: String
}

fileprivate extension AirshipHTTPResponse {
    var isOperationComplete: Bool {
        // Consider the operation complete if we have a success
        // response or a client error. The client error is to avoid
        // blocking the queue on either an invalid operation or
        // if the app is not configured to properly.
        return self.isSuccess || self.isClientError
    }
}
