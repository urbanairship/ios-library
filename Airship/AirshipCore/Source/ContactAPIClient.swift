/* Copyright Airship and Contributors */



/// NOTE: For internal use only. :nodoc:
protocol ContactsAPIClientProtocol: Sendable {
    func resolve(
        channelID: String,
        contactID: String?,
        possiblyOrphanedContactID: String?
    ) async throws ->  AirshipHTTPResponse<ContactIdentifyResult>

    func identify(
        channelID: String,
        namedUserID: String,
        contactID: String?,
        possiblyOrphanedContactID: String?
    ) async throws ->  AirshipHTTPResponse<ContactIdentifyResult>

    func reset(
        channelID: String,
        possiblyOrphanedContactID: String?
    ) async throws ->  AirshipHTTPResponse<ContactIdentifyResult>

    func update(
        contactID: String,
        tagGroupUpdates: [TagGroupUpdate]?,
        attributeUpdates: [AttributeUpdate]?,
        subscriptionListUpdates: [ScopedSubscriptionListUpdate]?
    ) async throws ->  AirshipHTTPResponse<Void>

    func associateChannel(
        contactID: String,
        channelID: String,
        channelType: ChannelType
    ) async throws ->  AirshipHTTPResponse<ContactAssociateChannelResult>

    func registerEmail(
        contactID: String,
        address: String,
        options: EmailRegistrationOptions,
        locale: Locale
    ) async throws ->  AirshipHTTPResponse<ContactAssociateChannelResult>

    func registerSMS(
        contactID: String,
        msisdn: String,
        options: SMSRegistrationOptions,
        locale: Locale
    ) async throws ->  AirshipHTTPResponse<ContactAssociateChannelResult>

    func registerOpen(
        contactID: String,
        address: String,
        options: OpenRegistrationOptions,
        locale: Locale
    ) async throws ->  AirshipHTTPResponse<ContactAssociateChannelResult>

    func disassociateChannel(
        contactID: String,
        disassociateOptions: DisassociateOptions
    ) async throws -> AirshipHTTPResponse<ContactDisassociateChannelResult>

    func resend(
        resendOptions: ResendOptions
    ) async throws ->  AirshipHTTPResponse<Bool>
}

/// NOTE: For internal use only. :nodoc:
final class ContactAPIClient: ContactsAPIClientProtocol {

    private let config: RuntimeConfig
    private let session: any AirshipRequestSession

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom({ (decoder) -> Date in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)

            guard let date = AirshipDateFormatter.date(fromISOString: dateStr) else {
                throw AirshipErrors.error("Invalid date \(dateStr)")
            }
            return date
        })
        return decoder
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom({ date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(
                AirshipDateFormatter.string(fromDate: date, format: .isoDelimitter)
            )
        })
        return encoder
    }

    init(config: RuntimeConfig, session: (any AirshipRequestSession)? = nil) {
        self.config = config
        self.session = session ?? config.requestSession
    }

    func resolve(
        channelID: String,
        contactID: String?,
        possiblyOrphanedContactID: String?
    ) async throws ->  AirshipHTTPResponse<ContactIdentifyResult> {
        return try await self.performIdentify(
            channelID: channelID,
            identifyRequest: .resolve(contactID: contactID, possiblyOrphanedContactID: possiblyOrphanedContactID)
        )
    }

    func reset(
        channelID: String,
        possiblyOrphanedContactID: String?
    ) async throws ->  AirshipHTTPResponse<ContactIdentifyResult> {
        return try await self.performIdentify(
            channelID: channelID,
            identifyRequest: .reset(possiblyOrphanedContactID: possiblyOrphanedContactID)
        )
    }

    func identify(
        channelID: String,
        namedUserID: String,
        contactID: String?,
        possiblyOrphanedContactID: String?
    ) async throws ->  AirshipHTTPResponse<ContactIdentifyResult> {
        return try await self.performIdentify(
            channelID: channelID,
            identifyRequest: .identify(namedUserID: namedUserID, contactID: contactID, possiblyOrphanedContactID: possiblyOrphanedContactID)
        )
    }

    func update(
        contactID: String,
        tagGroupUpdates: [TagGroupUpdate]?,
        attributeUpdates: [AttributeUpdate]?,
        subscriptionListUpdates: [ScopedSubscriptionListUpdate]?
    ) async throws ->  AirshipHTTPResponse<Void> {
        let requestBody = ContactUpdateRequestBody(
            attributes: try attributeUpdates?.toRequestBody(),
            tags: tagGroupUpdates?.toRequestBody(),
            subscriptionLists: subscriptionListUpdates?.toRequestBody(),
            associate: nil
        )

        return try await performUpdate(contactID: contactID, requestBody: requestBody)
    }

    func associateChannel(
        contactID: String,
        channelID: String,
        channelType: ChannelType
    ) async throws ->  AirshipHTTPResponse<ContactAssociateChannelResult> {
        let requestBody = ContactUpdateRequestBody(
            attributes: nil,
            tags: nil,
            subscriptionLists: nil,
            associate: [
                ContactUpdateRequestBody.AssociateChannelOperation(
                    deviceType: channelType,
                    channelID: channelID
                )
            ]
        )

        return try await performUpdate(
            contactID: contactID,
            requestBody: requestBody
        ).map { response in
            if (response.isSuccess) {
                return ContactAssociateChannelResult(channelType: channelType, channelID: channelID)
            } else {
                return nil
            }
        }
    }

    func registerEmail(
        contactID: String,
        address: String,
        options: EmailRegistrationOptions,
        locale: Locale
    ) async throws ->  AirshipHTTPResponse<ContactAssociateChannelResult> {
        return try await performChannelRegistration(
            contactID: contactID,
            requestBody: EmailChannelRegistrationBody(
                address: address,
                options: options,
                locale: locale,
                timezone: TimeZone.current.identifier
            ),
            channelType: .email
        )
    }

    func registerSMS(
        contactID: String,
        msisdn: String,
        options: SMSRegistrationOptions,
        locale: Locale
    ) async throws ->  AirshipHTTPResponse<ContactAssociateChannelResult> {
        return try await performChannelRegistration(
            contactID: contactID,
            requestBody: SMSRegistrationBody(
                msisdn: msisdn,
                options: options,
                locale: locale,
                timezone: TimeZone.current.identifier
            ),
            channelType: .sms
        )
    }

    func registerOpen(
        contactID: String,
        address: String,
        options: OpenRegistrationOptions,
        locale: Locale
    ) async throws ->  AirshipHTTPResponse<ContactAssociateChannelResult> {
        return try await performChannelRegistration(
            contactID: contactID,
            requestBody: OpenChannelRegistrationBody(
                address: address,
                options: options,
                locale: locale,
                timezone: TimeZone.current.identifier
            ),
            channelType: .open
        )
    }


    func disassociateChannel(
        contactID: String,
        disassociateOptions: DisassociateOptions
    ) async throws -> AirshipHTTPResponse<ContactDisassociateChannelResult> {

        return try await performDisassociate(
            contactID: contactID,
            requestBody: disassociateOptions
        )
    }

    func resend(resendOptions: ResendOptions) async throws -> AirshipHTTPResponse<Bool> {
        return try await performResend(resendOptions: resendOptions)
    }

    private func makeURL(path: String) throws -> URL {
        guard let deviceAPIURL = self.config.deviceAPIURL else {
            throw AirshipErrors.error("Initial config not resolved.")
        }

        let urlString = "\(deviceAPIURL)\(path)"

        guard let url = URL(string: "\(deviceAPIURL)\(path)") else {
            throw AirshipErrors.error("Invalid ContactAPIClient URL: \(String(describing: urlString))")
        }

        return url
    }

    private func makeChannelCreateURL(channelType: ChannelType) throws -> URL {
        switch(channelType) {
        case .email:
            return try self.makeURL(path: "/api/channels/restricted/email")
        case .open:
            return try self.makeURL(path: "/api/channels/restricted/open")
        case .sms:
            return try self.makeURL(path: "/api/channels/restricted/sms")
        }
    }

    private func performChannelRegistration<T: Encodable>(
        contactID: String,
        requestBody: T,
        channelType: ChannelType
    ) async throws ->  AirshipHTTPResponse<ContactAssociateChannelResult> {
        let request = AirshipRequest(
            url: try self.makeChannelCreateURL(channelType: channelType),
            headers: [
                "Accept":  "application/vnd.urbanairship+json; version=3;",
                "Content-Type": "application/json"
            ],
            method: "POST",
            auth: .generatedAppToken,
            body: try self.encoder.encode(requestBody)
        )

        let decoder = self.decoder
        let createResponse: AirshipHTTPResponse<ChannelCreateResult> = try await self.session.performHTTPRequest(
            request
        ) { (data, response) in

            AirshipLogger.debug("Channel \(channelType) created with response: \(response)")

            guard let data = data, response.statusCode == 200 || response.statusCode == 201 else {
                return nil
            }

            return try decoder.decode(ChannelCreateResult.self, from: data)
        }

        guard createResponse.isSuccess, let channelID = createResponse.result?.channelID else {
            return try createResponse.map { _ in return nil }
        }

        return try await associateChannel(
            contactID: contactID,
            channelID: channelID,
            channelType: channelType
        )
    }

    private func performIdentify(
        channelID: String,
        identifyRequest: ContactIdentifyRequestBody
    ) async throws ->  AirshipHTTPResponse<ContactIdentifyResult> {
        AirshipLogger.debug("Identifying contact for channel ID \(channelID) request \(identifyRequest)")

        let request = AirshipRequest(
            url: try makeURL(path: "/api/contacts/identify/v2"),
            headers: [
                "Accept": "application/vnd.urbanairship+json; version=3;",
                "Content-Type": "application/json",
            ],
            method: "POST",
            auth: .generatedChannelToken(identifier: channelID),
            body: try self.encoder.encode(identifyRequest)
        )

        let decoder = self.decoder
        return try await session.performHTTPRequest(request) { (data, response) in

            AirshipLogger.debug("Contact identify request finished with response: \(response)")

            guard response.statusCode == 200, let data = data else {
                return nil
            }

            return try decoder.decode(ContactIdentifyResult.self, from: data)
        }
    }

    private func performDisassociate(
        contactID: String,
        requestBody: DisassociateOptions
    ) async throws -> AirshipHTTPResponse<ContactDisassociateChannelResult> {
        AirshipLogger.debug("Disassociating with \(requestBody)")

        let encodedRequestBody = try self.encoder.encode(requestBody)
        let requestBodyString = String(data: encodedRequestBody, encoding: .utf8)
        AirshipLogger.debug("Encoded request body: \(requestBodyString ?? "Unable to convert data to string")")

        let request =  AirshipRequest(
            url: try self.makeURL(path: "/api/contacts/disassociate/\(contactID)"),
            headers: [
                "Accept": "application/vnd.urbanairship+json; version=3;",
                "Content-Type": "application/json"
            ],
            method: "POST",
            auth: .basicAppAuth,
            body: encodedRequestBody
        )

        let decoder = self.decoder
        return try await session.performHTTPRequest(request) { (data, response) in
            AirshipLogger.debug("Update finished with response: \(response)")

            guard response.statusCode == 200, let data = data else {
                return nil
            }

            return try decoder.decode(ContactDisassociateChannelResult.self, from: data)
        }
    }

    private func performResend(
        resendOptions: ResendOptions
    ) async throws -> AirshipHTTPResponse<Bool> {
        let requestBodyData: Data?

        switch resendOptions {
        case .channel(let channel):
            requestBodyData = try self.encoder.encode(channel)
        case .email(let email):
            requestBodyData = try self.encoder.encode(email)
        case .sms(let sms):
            requestBodyData = try self.encoder.encode(sms)
        }

        guard let requestBodyData = requestBodyData else {
            throw AirshipErrors.error("Unable to encode resend operation data.")
        }

        AirshipLogger.debug("Re-sending double opt-in message")

        let request =  AirshipRequest(
            url: try self.makeURL(path: "/api/channels/resend"),
            headers: [
                "Accept": "application/vnd.urbanairship+json; version=3;",
                "Content-Type": "application/json"
            ],
            method: "POST",
            auth: .generatedAppToken,
            body: requestBodyData
        )

        return try await session.performHTTPRequest(request) { (data, response) in

            AirshipLogger.debug("Update finished with response: \(response)")

            return nil
        }
    }

    private func performUpdate(
        contactID: String,
        requestBody: ContactUpdateRequestBody
    ) async throws -> AirshipHTTPResponse<Void> {
        AirshipLogger.debug("Updating contact \(contactID) with \(requestBody)")

        let request =  AirshipRequest(
            url: try self.makeURL(path: "/api/contacts/\(contactID)"),
            headers: [
                "Accept": "application/vnd.urbanairship+json; version=3;",
                "Content-Type": "application/json",
                "X-UA-Appkey": self.config.appCredentials.appKey
            ],
            method: "POST",
            auth: .contactAuthToken(identifier: contactID),
            body: try self.encoder.encode(requestBody)
        )

        return try await session.performHTTPRequest(request) { (data, response) in

            AirshipLogger.debug("Update finished with response: \(response)")

            return nil
        }
    }
}

struct ContactIdentifyResult: Decodable, Equatable {
    let contact: ContactInfo
    let token: String
    let tokenExpiresInMilliseconds: UInt

    enum CodingKeys: String, CodingKey {
        case tokenExpiresInMilliseconds = "token_expires_in"
        case token = "token"
        case contact = "contact"
    }

    struct ContactInfo: Decodable, Equatable {
        let channelAssociatedDate: Date
        let contactID: String
        let isAnonymous: Bool

        enum CodingKeys: String, CodingKey {
            case channelAssociatedDate = "channel_association_timestamp"
            case contactID = "contact_id"
            case isAnonymous = "is_anonymous"
        }
    }
}

struct ContactAssociateChannelResult: Decodable, Equatable {
   public let channelType: ChannelType
   public let channelID: String
}

struct ContactDisassociateChannelResult: Decodable, Equatable {
   public let channelID: String

    enum CodingKeys: String, CodingKey {
        case channelID = "channel_id"
    }
}

enum DisassociateOptions: Sendable, Equatable, Codable, Hashable {
    case channel(Channel)
    case email(Email)
    case sms(SMS)

    init(channelID: String, channelType: ChannelType, optOut: Bool) {
        self = .channel(Channel(channelID: channelID, optOut: optOut, channelType: channelType))
    }

    init(emailAddress: String, optOut: Bool) {
        self = .email(Email(address: emailAddress, optOut: optOut))
    }

    init(msisdn: String, senderID: String, optOut: Bool) {
        self = .sms(SMS(msisdn: msisdn, senderID: senderID, optOut: optOut))
    }

    struct Channel: Sendable, Equatable, Codable, Hashable {
        let channelID: String
        let optOut: Bool
        let channelType: ChannelType

        enum CodingKeys: String, CodingKey {
            case channelID = "channel_id"
            case optOut = "opt_out"
            case channelType = "channel_type"
        }
    }

    struct Email: Sendable, Equatable, Codable, Hashable {
        let channelType: String = "email"
        let address: String
        let optOut: Bool

        enum CodingKeys: String, CodingKey {
            case address = "email_address"
            case optOut = "opt_out"
            case channelType = "channel_type"
        }
    }

    struct SMS: Sendable, Equatable, Codable, Hashable {
        let channelType: String = "sms"
        let msisdn: String
        let senderID: String
        let optOut: Bool

        enum CodingKeys: String, CodingKey {
            case msisdn = "msisdn"
            case senderID = "sender"
            case optOut = "opt_out"
            case channelType = "channel_type"
        }
    }

    enum CodingKeys: String, CodingKey {
        case channel
        case email
        case sms
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .channel(let channel):
            try container.encode(channel)
        case .email(let email):
            try container.encode(email)
        case .sms(let sms):
            try container.encode(sms)
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let channel = try? container.decode(Channel.self) {
            self = .channel(channel)
        } else if let email = try? container.decode(Email.self) {
            self = .email(email)
        } else if let sms = try? container.decode(SMS.self) {
            self = .sms(sms)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid data for DisassociateOptions")
        }
    }
}

enum ResendOptions: Sendable, Equatable, Codable, Hashable {
    case channel(Channel)
    case email(Email)
    case sms(SMS)

    init(channelID: String, channelType: ChannelType) {
        self = .channel(Channel(channelType: channelType, channelID: channelID))
    }

    init(emailAddress: String) {
        self = .email(Email(address: emailAddress))
    }

    init(msisdn: String, senderID: String) {
        self = .sms(SMS(msisdn: msisdn, senderID: senderID))
    }

    struct Channel: Sendable, Equatable, Codable, Hashable {
        let channelType: ChannelType
        let channelID: String

        enum CodingKeys: String, CodingKey {
            case channelType = "channel_type"
            case channelID = "channel_id"
        }
    }

    struct Email: Sendable, Equatable, Codable, Hashable {
        let channelType: String = "email"
        let address: String

        enum CodingKeys: String, CodingKey {
            case address = "email_address"
            case channelType = "channel_type"
        }
    }

    struct SMS: Sendable, Equatable, Codable, Hashable {
        let channelType: String = "sms"
        let msisdn: String
        let senderID: String

        enum CodingKeys: String, CodingKey {
            case channelType = "channel_type"
            case msisdn = "msisdn"
            case senderID = "sender"
        }
    }
}

fileprivate struct ContactUpdateRequestBody: Encodable {
    let attributes: [AttributeOperation]?
    let tags: TagUpdates?
    let subscriptionLists: [SubscriptionListOperation]?
    let associate: [AssociateChannelOperation]?

    enum CodingKeys: String, CodingKey {
        case attributes = "attributes"
        case tags = "tags"
        case subscriptionLists = "subscription_lists"
        case associate = "associate"
    }

    enum AttributeOperationAction: String, Encodable {
        case set
        case remove
    }

    struct AttributeOperation: Encodable {
        let action: AttributeOperationAction
        let key: String
        let value: AirshipJSON?
        let timestamp: Date
    }

    struct TagUpdates: Encodable {
        let adds: [String: [String]]?
        let removes: [String: [String]]?
        let sets: [String: [String]]?

        enum CodingKeys: String, CodingKey {
            case adds = "add"
            case removes = "remove"
            case sets = "set"
        }
    }

    enum SubscriptionListOperationAction: String, Encodable {
        case subscribe
        case unsubscribe
    }

    struct SubscriptionListOperation: Encodable {
        let action: SubscriptionListOperationAction
        let scope: ChannelScope
        let timestamp: Date
        let listID: String

        enum CodingKeys: String, CodingKey {
            case action
            case scope
            case timestamp
            case listID = "list_id"
        }
    }

    struct AssociateChannelOperation: Encodable {
        let deviceType: ChannelType
        let channelID: String

        enum CodingKeys: String, CodingKey {
            case deviceType = "device_type"
            case channelID = "channel_id"
        }
    }
}


fileprivate struct ContactIdentifyRequestBody: Encodable {
    private let deviceInfo = DeviceInfo()
    private let action: RequestAction

    internal init(action: RequestAction) {
        self.action = action
    }

    static func identify(namedUserID: String, contactID: String?, possiblyOrphanedContactID: String?) -> ContactIdentifyRequestBody {
        return ContactIdentifyRequestBody(
            action: RequestAction(type: "identify", namedUserID: namedUserID, contactID: contactID, possiblyOrphanedContactID: possiblyOrphanedContactID)
        )
    }

    static func reset(possiblyOrphanedContactID: String?) -> ContactIdentifyRequestBody {
        return ContactIdentifyRequestBody(
            action: RequestAction(type: "reset", namedUserID: nil, contactID: nil, possiblyOrphanedContactID: possiblyOrphanedContactID)
        )
    }

    static func resolve(contactID: String?, possiblyOrphanedContactID: String?) -> ContactIdentifyRequestBody {
        return ContactIdentifyRequestBody(
            action: RequestAction(type: "resolve", namedUserID: nil, contactID: contactID, possiblyOrphanedContactID: possiblyOrphanedContactID)
        )
    }

    enum CodingKeys: String, CodingKey {
        case deviceInfo = "device_info"
        case action = "action"
    }

    internal struct DeviceInfo: Codable {
        let deviceType = "ios"

        enum CodingKeys: String, CodingKey {
            case deviceType = "device_type"
        }
    }

    internal struct RequestAction: Codable {
        let type: String
        let namedUserID: String?
        let contactID: String?
        let possiblyOrphanedContactID: String?

        enum CodingKeys: String, CodingKey {
            case type = "type"
            case namedUserID = "named_user_id"
            case contactID = "contact_id"
            case possiblyOrphanedContactID = "possibly_orphaned_contact_id"
        }
    }
}

fileprivate struct OpenChannelRegistrationBody: Encodable {
    let channel: ChannelPayload

    init(
        address: String,
        options: OpenRegistrationOptions,
        locale: Locale,
        timezone: String
    ) {

        self.channel = ChannelPayload(
            address: address,
            timezone: timezone,
            localeCountry: locale.getRegionCode(),
            localeLanguage: locale.getLanguageCode(),
            openInfo: OpenPayload(
                platformName: options.platformName,
                identifiers: options.identifiers
            )
        )
    }

    internal struct ChannelPayload: Encodable {
        let type = "open"
        let optIn = true
        let address: String
        let timezone: String
        let localeCountry: String?
        let localeLanguage: String?
        let openInfo: OpenPayload

        enum CodingKeys: String, CodingKey {
            case type
            case optIn = "opt_in"
            case address
            case timezone
            case localeCountry = "locale_country"
            case localeLanguage  = "locale_language"
            case openInfo = "open"
        }
    }

    internal struct OpenPayload: Encodable {
        let platformName: String
        let identifiers: [String: String]?

        enum CodingKeys: String, CodingKey {
            case platformName = "open_platform_name"
            case identifiers
        }
    }
}

fileprivate struct EmailChannelUpdateBody: Encodable {
    let channel: ChannelPartialPayload

    let optInMode: String = "double"

    enum CodingKeys: String, CodingKey {
        case channel
        case optInMode = "opt_in_mode"
    }

    internal struct ChannelPartialPayload: Encodable {
        let type: String

        enum CodingKeys: String, CodingKey {
            case type
        }
    }

}

fileprivate struct EmailChannelRegistrationBody: Encodable {
    let channel: ChannelPayload
    let properties: AirshipJSON?
    let optInMode: OptInMode

    init(
        address: String,
        options: EmailRegistrationOptions,
        locale: Locale,
        timezone: String
    ) {
        self.channel = ChannelPayload(
            address: address,
            timezone: timezone,
            localeCountry: locale.getRegionCode(),
            localeLanguage: locale.getLanguageCode(),
            commercialOptedIn: options.commercialOptedIn,
            transactionalOptedIn: options.transactionalOptedIn
        )

        self.optInMode = options.doubleOptIn ? .double : .classic
        self.properties = options.properties
    }

    enum CodingKeys: String, CodingKey {
        case channel
        case properties
        case optInMode = "opt_in_mode"
    }

    internal enum OptInMode: String, Encodable {
        case classic
        case double
    }

    internal struct ChannelPayload: Encodable {
        let type = "email"
        let address: String
        let timezone: String
        let localeCountry: String?
        let localeLanguage: String?
        let commercialOptedIn: Date?
        let transactionalOptedIn: Date?

        enum CodingKeys: String, CodingKey {
            case type
            case address
            case timezone
            case localeCountry = "locale_country"
            case localeLanguage  = "locale_language"
            case commercialOptedIn = "commercial_opted_in"
            case transactionalOptedIn = "transactional_opted_in"
        }
    }

    internal struct OpenPayload: Encodable {
        let platformName: String
        let identifiers: [String: String]?

        enum CodingKeys: String, CodingKey {
            case platformName = "open_platform_name"
            case identifiers
        }
    }
}

fileprivate struct SMSRegistrationBody: Encodable {
    let msisdn: String
    let sender: String
    let timezone: String
    let localeCountry: String?
    let localeLanguage: String?

    init(
        msisdn: String,
        options: SMSRegistrationOptions,
        locale: Locale,
        timezone: String
    ) {
        self.msisdn = msisdn
        self.sender = options.senderID
        self.timezone = timezone
        self.localeCountry = locale.getRegionCode()
        self.localeLanguage = locale.getLanguageCode()
    }

    enum CodingKeys: String, CodingKey {
        case msisdn
        case sender
        case timezone
        case localeCountry = "locale_country"
        case localeLanguage  = "locale_language"
    }
}


fileprivate struct ChannelCreateResult: Decodable {
    let channelID: String

    enum CodingKeys: String, CodingKey {
        case channelID = "channel_id"
    }
}


fileprivate extension Array where Element == TagGroupUpdate {
    func toRequestBody() -> ContactUpdateRequestBody.TagUpdates? {
        var adds: [String: [String]] = [:]
        var removes: [String: [String]] = [:]
        var sets: [String: [String]] = [:]


        self.forEach { update in
            switch update.type {
            case .add:
                adds[update.group] = update.tags
            case .remove:
                removes[update.group] = update.tags
            case .set:
                sets[update.group] = update.tags
            }
        }

        guard !adds.isEmpty || !removes.isEmpty || !sets.isEmpty else {
            return nil
        }

        return ContactUpdateRequestBody.TagUpdates(
            adds: adds.isEmpty ? nil : adds,
            removes: removes.isEmpty ? nil : removes,
            sets: sets.isEmpty ? nil : sets
        )
    }
}


fileprivate extension Array where Element == ScopedSubscriptionListUpdate {
    func toRequestBody() -> [ContactUpdateRequestBody.SubscriptionListOperation]? {
        let mapped = self.map { update in
            switch(update.type) {
            case .subscribe:
                return ContactUpdateRequestBody.SubscriptionListOperation(
                    action: .subscribe,
                    scope: update.scope,
                    timestamp: update.date,
                    listID: update.listId
                )
            case .unsubscribe:
                return ContactUpdateRequestBody.SubscriptionListOperation(
                    action: .unsubscribe,
                    scope: update.scope,
                    timestamp: update.date,
                    listID: update.listId
                )
            }
        }

        guard !mapped.isEmpty else {
            return nil
        }

        return mapped
    }
}

fileprivate extension Array where Element == AttributeUpdate {
    func toRequestBody() throws -> [ContactUpdateRequestBody.AttributeOperation]? {
        let mapped = self.map { update in
            switch(update.type) {
            case .set:
                return ContactUpdateRequestBody.AttributeOperation(
                    action: .set,
                    key: update.attribute,
                    value: update.jsonValue,
                    timestamp: update.date
                )
            case .remove:
                return ContactUpdateRequestBody.AttributeOperation(
                    action: .remove,
                    key: update.attribute,
                    value: nil,
                    timestamp: update.date
                )
            }
        }

        guard !mapped.isEmpty else {
            return nil
        }

        return mapped
    }
}
