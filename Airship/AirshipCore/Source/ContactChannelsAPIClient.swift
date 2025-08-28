/* Copyright Airship and Contributors */



// NOTE: For internal use only. :nodoc:
public protocol ContactChannelsAPIClientProtocol: Sendable {
    func fetchAssociatedChannelsList(
        contactID: String
    ) async throws -> AirshipHTTPResponse<[ContactChannel]>
}

// NOTE: For internal use only. :nodoc:
final class ContactChannelsAPIClient: ContactChannelsAPIClientProtocol {
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
    
    init(config: RuntimeConfig, session: any AirshipRequestSession) {
        self.config = config
        self.session = session
    }
    
    convenience init(config: RuntimeConfig) {
        self.init(config: config, session: config.requestSession)
    }

    func fetchAssociatedChannelsList(
        contactID: String
    ) async throws -> AirshipHTTPResponse<[ContactChannel]> {
        AirshipLogger.debug("Retrieving associated channels list")

        let request = AirshipRequest(
            url: try self.makeURL(path: "/api/contacts/associated_types/\(contactID)"),
            headers: [
                "Accept": "application/vnd.urbanairship+json; version=3;",
                "Content-Type": "application/json"
            ],
            method: "GET",
            auth: .contactAuthToken(identifier: contactID)
        )

        return try await self.session.performHTTPRequest(
            request
        ) { (data, response) in

            AirshipLogger.debug("Fetching associated channels list finished with response: \(response)")

            guard response.statusCode == 200, let data = data else {
                return nil
            }


            let result = try self.decoder.decode(
                ContactChannelsResponseBody.self,
                from: data
            )

            return result.channels.compactMap { channel in
                channel.contactChannel
            }
        }
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
}

fileprivate struct ContactChannelsResponseBody: Decodable, Sendable {
    let channels: [Channel]

    enum CodingKeys: String, CodingKey {
        case channels = "channels"
    }
    
    enum Channel: Decodable, Sendable {
        case sms(SMSChannel)
        case email(EmailChannel)
        case unknown

        enum DeviceType: String, Decodable, Sendable {
            case email
            case sms
        }

        enum CodingKeys: String, CodingKey {
            case deviceType = "type"
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let deviceType = try? container.decode(DeviceType.self, forKey: .deviceType)
            let singleValueContainer = try decoder.singleValueContainer()
            guard let deviceType else {
                self = .unknown
                return
            }

            switch (deviceType) {
            case .email:
                self = .email(
                    try singleValueContainer.decode(EmailChannel.self)
                )
            case .sms:
                self = .sms(
                    try singleValueContainer.decode(SMSChannel.self)
                )
            }
        }
    }

    struct SMSChannel: Decodable, Sendable {
        var channelID: String
        var sender: String
        var isOptIn: Bool
        var deIdentifiedAddress: String


        enum CodingKeys: String, CodingKey {
            case channelID = "channel_id"
            case isOptIn = "opt_in"
            case sender = "sender"
            case deIdentifiedAddress = "msisdn"
        }
    }

    struct EmailChannel: Decodable, Sendable {
        var channelID: String
        var deIdentifiedAddress: String
        var commericalOptedIn: Date?
        var commericalOptedOut: Date?

        var transactionalOptedIn: Date?
        var transactionalOptedOut: Date?


        enum CodingKeys: String, CodingKey {
            case channelID = "channel_id"
            case deIdentifiedAddress = "email_address"
            case commericalOptedIn = "commercial_opted_in"
            case commericalOptedOut = "commercial_opted_out"
            case transactionalOptedIn = "transactional_opted_in"
            case transactionalOptedOut = "transactional_opted_out"
        }
    }
}

fileprivate extension ContactChannelsResponseBody.Channel {
    var contactChannel: ContactChannel? {
        switch(self) {
        case .email(let email):
            return .email(
                .registered(
                    ContactChannel.Email.Registered(
                        channelID: email.channelID,
                        maskedAddress: email.deIdentifiedAddress,
                        transactionalOptedIn: email.transactionalOptedIn,
                        transactionalOptedOut: email.transactionalOptedOut,
                        commercialOptedIn: email.commericalOptedIn,
                        commercialOptedOut: email.commericalOptedOut
                    )
                )
            )
        case .sms(let sms):
            return .sms(
                .registered(
                    ContactChannel.Sms.Registered(
                        channelID: sms.channelID,
                        maskedAddress: sms.deIdentifiedAddress,
                        isOptIn: sms.isOptIn,
                        senderID: sms.sender
                    )
                )
            )
        case .unknown:
            return nil
        }
    }
}
