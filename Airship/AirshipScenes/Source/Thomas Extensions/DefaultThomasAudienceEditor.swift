/* Copyright Airship and Contributors */

@_spi(AirshipInternal) import AirshipSceneRenderer
@_spi(AirshipInternal) import AirshipCore
import AirshipBasement
import Foundation

/// The audience editor the SDK wires up by default — applies form-submission results through the
/// shared `Airship.contact` / `Airship.channel`.
/// - Note: For internal use only. :nodoc:
@MainActor
struct DefaultThomasAudienceEditor: ThomasAudienceEditor {
    public init() {}

    public func registerChannels(_ channels: [ThomasChannelRegistration]) {
        channels.forEach { channelRegistration in
            switch channelRegistration {
            case .email(let address, let options):
                Airship.contact.registerEmail(
                    address,
                    options: options.makeContactOptions()
                )
            case .sms(let address, let options):
                Airship.contact.registerSMS(
                    address,
                    options: options.makeContactOptions()
                )
            @unknown default:
                AirshipLogger.error("Unexpected channel registration \(channelRegistration)")
            }
        }
    }

    public func applyAttributes(_ attributes: [ThomasAttribute]) {
        guard !attributes.isEmpty else { return }
        let channelEditor = Airship.channel.editAttributes()
        let contactEditor = Airship.contact.editAttributes()

        attributes.forEach { attribute in
            if let name = attribute.attributeName.channel {
                channelEditor.set(
                    attributeValue: attribute.attributeValue,
                    attribute: name
                )
            }

            if let name = attribute.attributeName.contact {
                contactEditor.set(
                    attributeValue: attribute.attributeValue,
                    attribute: name
                )
            }
        }

        channelEditor.apply()
        contactEditor.apply()
    }
}


extension AttributesEditor {
    func set(
        attributeValue: ThomasAttributeValue,
        attribute: String
    ) {
        switch attributeValue {
        case .string(let value):
            self.set(string: value, attribute: attribute)

        case .number(let value):
            self.set(double: value, attribute: attribute)
        @unknown default:
            AirshipLogger.error("Unexpected attribute value \(attributeValue)")
        }
    }
}

extension ThomasEmailRegistrationOption {
    func makeContactOptions(date: Date = Date.now) -> EmailRegistrationOptions {
        switch (self) {
        case .commercial(let properties):
            return .commercialOptions(
                transactionalOptedIn: nil,
                commercialOptedIn: properties.optedIn ? date : nil,
                properties: properties.properties?.unWrap() as? [String: Any]
            )
        case .doubleOptIn(let properties):
            return .options(
                properties: properties.properties?.unWrap() as? [String: Any],
                doubleOptIn: true
            )
        case .transactional(let properties):
            return .options(
                transactionalOptedIn: nil,
                properties: properties.properties?.unWrap() as? [String: Any],
                doubleOptIn: false
            )
        }
    }
}

extension ThomasSMSRegistrationOption {
    func makeContactOptions(date: Date = Date.now) -> SMSRegistrationOptions {
        switch (self) {
        case .optIn(let properties):
            return .optIn(senderID: properties.senderID)
        }
    }
}
