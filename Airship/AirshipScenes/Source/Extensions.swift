/* Copyright Airship and Contributors */

@_spi(AirshipInternal) import AirshipSceneRenderer
import AirshipCore
import Foundation

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
