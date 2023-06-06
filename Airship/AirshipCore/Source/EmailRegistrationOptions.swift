/* Copyright Airship and Contributors */

import Foundation

/// Email registration options
@objc(UAEmailRegistrationOptions)
public final class EmailRegistrationOptions: NSObject, Codable, Sendable {

    /**
     * Transactional opted-in value
     */
    let transactionalOptedIn: Date?

    /**
     * Commercial opted-in value
     */
    let commercialOptedIn: Date?

    /**
     * Properties
     */
    let properties: AirshipJSON?

    /**
     * Double opt-in value
     */
    let doubleOptIn: Bool

    private init(
        transactionalOptedIn: Date?,
        commercialOptedIn: Date? = nil,
        properties: [String: Any]?,
        doubleOptIn: Bool = false
    ) {
        self.transactionalOptedIn = transactionalOptedIn
        self.commercialOptedIn = commercialOptedIn
        self.properties = try? AirshipJSON.wrap(properties)
        self.doubleOptIn = doubleOptIn
    }

    /// Returns an Email registration options with double opt-in value to false
    /// - Parameter transactionalOptedIn: The transactional opted-in value
    /// - Parameter commercialOptedIn: The commercial opted-in value
    /// - Parameter properties: The properties. They must be JSON serializable.
    /// - Returns: An Email registration options.
    @objc
    public static func commercialOptions(
        transactionalOptedIn: Date?,
        commercialOptedIn: Date?,
        properties: [String: Any]?
    ) -> EmailRegistrationOptions {
        return EmailRegistrationOptions(
            transactionalOptedIn: transactionalOptedIn,
            commercialOptedIn: commercialOptedIn,
            properties: properties
        )
    }

    /// Returns an Email registration options.
    /// - Parameter transactionalOptedIn: The transactional opted-in date.
    /// - Parameter properties: The properties. They must be JSON serializable.
    /// - Parameter doubleOptIn: The double opt-in value
    /// - Returns: An Email registration options.
    @objc
    public static func options(
        transactionalOptedIn: Date?,
        properties: [String: Any]?,
        doubleOptIn: Bool
    ) -> EmailRegistrationOptions {
        return EmailRegistrationOptions(
            transactionalOptedIn: transactionalOptedIn,
            properties: properties,
            doubleOptIn: doubleOptIn
        )
    }

    /// Returns an Email registration options.
    /// - Parameter properties: The properties. They must be JSON serializable.
    /// - Parameter doubleOptIn: The double opt-in value
    /// - Returns: An Email registration options.
    @objc
    public static func options(
        properties: [String: Any]?,
        doubleOptIn: Bool
    ) -> EmailRegistrationOptions {
        return EmailRegistrationOptions(
            transactionalOptedIn: nil,
            properties: properties,
            doubleOptIn: doubleOptIn
        )
    }

    enum CodingKeys: String, CodingKey {
        case transactionalOptedIn
        case commercialOptedIn
        case properties = "properties"
        case doubleOptIn
    }


    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.transactionalOptedIn = try container.decodeIfPresent(Date.self, forKey: .transactionalOptedIn)
        self.commercialOptedIn = try container.decodeIfPresent(Date.self, forKey: .commercialOptedIn)


        self.doubleOptIn = try container.decode(Bool.self, forKey: .doubleOptIn)

        do {
            self.properties = try container.decodeIfPresent(AirshipJSON.self, forKey: .properties)
        } catch {
            let legacy = try? container.decodeIfPresent(JsonValue.self, forKey: .properties)
            guard let legacy = legacy else {
                throw error
            }

            if let decoder = decoder as? JSONDecoder {
                self.properties = try AirshipJSON.from(
                    json: legacy.jsonEncodedValue,
                    decoder: decoder
                )
            } else {
                self.properties = try AirshipJSON.from(
                    json: legacy.jsonEncodedValue
                )
            }
        }
    }


    // Migration purposes
    fileprivate struct JsonValue: Decodable {
        let jsonEncodedValue: String?
    }

    func isEqual(to options: EmailRegistrationOptions) -> Bool {
        return doubleOptIn == options.doubleOptIn &&
        properties == options.properties &&
        commercialOptedIn == options.commercialOptedIn &&
        transactionalOptedIn == options.transactionalOptedIn
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let options = object as? EmailRegistrationOptions else {
            return false
        }

        if self === options {
            return true
        }

        return isEqual(to: options)
    }

    func hash() -> Int {
        var result = 1
        result = 31 * result + doubleOptIn.hashValue
        result = 31 * result + properties.hashValue
        result = 31 * result + commercialOptedIn.hashValue
        result = 31 * result + transactionalOptedIn.hashValue
        return result
    }
}
