/* Copyright Airship and Contributors */

import Foundation


// NOTE: For internal use only. :nodoc:
enum ContactOperation: Codable, Equatable, Sendable {

    var type: OperationType {
        switch (self) {
        case .update(_, _, _): return .update
        case .identify(_): return .identify
        case .resolve: return .resolve
        case .reset: return .reset
        case .registerEmail(_, _): return .registerEmail
        case .registerSMS(_, _): return .registerSMS
        case .registerOpen(_, _): return .registerOpen
        case .associateChannel(_, _): return .associateChannel
        }
    }

    enum OperationType: String, Codable {
        case update
        case identify
        case resolve
        case reset
        case registerEmail
        case registerSMS
        case registerOpen
        case associateChannel
    }

    case update(
        tagUpdates: [TagGroupUpdate]? = nil,
        attributeUpdates: [AttributeUpdate]? = nil,
        subscriptionListsUpdates: [ScopedSubscriptionListUpdate]? = nil
    )
    case identify(String)
    case resolve
    case reset
    case registerEmail(
        address: String,
        options: EmailRegistrationOptions
    )

    case registerSMS(
        msisdn: String,
        options: SMSRegistrationOptions
    )

    case registerOpen(
        address: String,
        options: OpenRegistrationOptions
    )

    case associateChannel(
        channelID: String,
        channelType: ChannelType
    )


    enum CodingKeys: String, CodingKey {
        case payload
        case type
    }

    enum PayloadCodingKeys: String, CodingKey {
        case tagUpdates
        case attrubuteUpdates
        case attributeUpdates
        case subscriptionListsUpdates
        case address
        case options
        case msisdn
        case identifier
        case channelID
        case channelType
    }


    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .update(let tagUpdates, let attributeUpdates, let subscriptionListsUpdates):
            var payloadContainer = container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .payload)
            try payloadContainer.encodeIfPresent(tagUpdates, forKey: .tagUpdates)
            try payloadContainer.encodeIfPresent(attributeUpdates, forKey: .attributeUpdates)
            try payloadContainer.encodeIfPresent(subscriptionListsUpdates, forKey: .subscriptionListsUpdates)
            try container.encode(OperationType.update, forKey: .type)

        case .identify(let identifier):
            var payloadContainer = container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .payload)
            try payloadContainer.encode(identifier, forKey: .identifier)
            try container.encode(OperationType.identify, forKey: .type)

        case .resolve:
            try container.encodeNil(forKey: .payload)
            try container.encode(OperationType.resolve, forKey: .type)

        case .reset:
            try container.encodeNil(forKey: .payload)
            try container.encode(OperationType.reset, forKey: .type)

        case .registerEmail(let address, let options):
            var payloadContainer = container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .payload)
            try payloadContainer.encode(address, forKey: .address)
            try payloadContainer.encode(options, forKey: .options)
            try container.encode(OperationType.registerEmail, forKey: .type)

        case .registerSMS(let msisdn, let options):
            var payloadContainer = container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .payload)
            try payloadContainer.encode(msisdn, forKey: .msisdn)
            try payloadContainer.encode(options, forKey: .options)
            try container.encode(OperationType.registerSMS, forKey: .type)

        case .registerOpen(let address, let options):
            var payloadContainer = container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .payload)
            try payloadContainer.encode(address, forKey: .address)
            try payloadContainer.encode(options, forKey: .options)
            try container.encode(OperationType.registerOpen, forKey: .type)

        case .associateChannel(let channelID, let channelType):
            var payloadContainer = container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .payload)
            try payloadContainer.encode(channelID, forKey: .channelID)
            try payloadContainer.encode(channelType, forKey: .channelType)
            try container.encode(OperationType.associateChannel, forKey: .type)
        }


    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(OperationType.self, forKey: .type)

        switch type {
        case .update:
            let payloadContainer = try container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .payload)
            self = .update(
                tagUpdates: try payloadContainer.decodeIfPresent(
                    [TagGroupUpdate].self,
                    forKey: .tagUpdates
                ),
                attributeUpdates: try payloadContainer.decodeIfPresent(
                    [AttributeUpdate].self,
                    forKey: .attributeUpdates
                ) ?? payloadContainer.decodeIfPresent(
                    [AttributeUpdate].self,
                    forKey: .attrubuteUpdates
                ),
                subscriptionListsUpdates: try payloadContainer.decodeIfPresent(
                    [ScopedSubscriptionListUpdate].self,
                    forKey: .subscriptionListsUpdates
                )
            )
        case .identify:
            let payloadContainer = try container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .payload)
            self = .identify(
                try payloadContainer.decode(
                    String.self,
                    forKey: .identifier
                )
            )

        case .registerEmail:
            let payloadContainer = try container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .payload)
            self = .registerEmail(
                address: try payloadContainer.decode(
                    String.self,
                    forKey: .address
                ),
                options: try payloadContainer.decode(
                    EmailRegistrationOptions.self,
                    forKey: .options
                )
            )
        case .registerSMS:
            let payloadContainer = try container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .payload)
            self = .registerSMS(
                msisdn: try payloadContainer.decode(
                    String.self,
                    forKey: .msisdn
                ),
                options: try payloadContainer.decode(
                    SMSRegistrationOptions.self,
                    forKey: .options
                )
            )

        case .registerOpen:
            let payloadContainer = try container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .payload)
            self = .registerOpen(
                address: try payloadContainer.decode(
                    String.self,
                    forKey: .address
                ),
                options: try payloadContainer.decode(
                    OpenRegistrationOptions.self,
                    forKey: .options
                )
            )

        case .associateChannel:
            let payloadContainer = try container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .payload)
            self = .associateChannel(
                channelID: try payloadContainer.decode(
                    String.self,
                    forKey: .channelID
                ),
                channelType: try payloadContainer.decode(
                    ChannelType.self,
                    forKey: .channelType
                )
            )
        case .resolve:
            self = .resolve
        case .reset:
            self = .reset
        }
    }
}

