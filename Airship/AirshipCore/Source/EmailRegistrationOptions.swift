/* Copyright Airship and Contributors */

public import Foundation

/// Email registration options
public struct EmailRegistrationOptions: Codable, Sendable, Equatable, Hashable {

    /// An email tracking choice. nil in its place sends neither date, leaving the project default
    /// or the channel's earlier choice.
    public enum TrackingConsent: Sendable, Equatable, Hashable {
        /// Opted in to tracking as of the date.
        case optedIn(Date)
        /// Opted out of tracking as of the date.
        case optedOut(Date)
    }

    /**
     * Transactional opted-in value
     */
    let transactionalOptedIn: Date?

    /**
     * Commercial opted-in value - used to determine the email opt-in state during double opt-in
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

    let openTrackingOptedIn: Date?
    let openTrackingOptedOut: Date?
    let clickTrackingOptedIn: Date?
    let clickTrackingOptedOut: Date?

    private init(
        transactionalOptedIn: Date?,
        commercialOptedIn: Date? = nil,
        properties: [String: Any]?,
        doubleOptIn: Bool = false,
        openTracking: TrackingConsent?,
        clickTracking: TrackingConsent?
    ) {
        self.transactionalOptedIn = transactionalOptedIn
        self.commercialOptedIn = commercialOptedIn
        self.properties = try? AirshipJSON.wrap(properties)
        self.doubleOptIn = doubleOptIn
        self.openTrackingOptedIn = openTracking?.optedInDate
        self.openTrackingOptedOut = openTracking?.optedOutDate
        self.clickTrackingOptedIn = clickTracking?.optedInDate
        self.clickTrackingOptedOut = clickTracking?.optedOutDate
    }

    /// Returns an Email registration options with double opt-in value to false
    /// - Parameter transactionalOptedIn: The transactional opted-in value
    /// - Parameter commercialOptedIn: The commercial opted-in value
    /// - Parameter properties: The properties. They must be JSON serializable.
    /// - Parameter openTracking: The open tracking consent, or nil to send none.
    /// - Parameter clickTracking: The click tracking consent, or nil to send none.
    /// - Returns: An Email registration options.
    public static func commercialOptions(
        transactionalOptedIn: Date?,
        commercialOptedIn: Date?,
        properties: [String: Any]?,
        openTracking: TrackingConsent? = nil,
        clickTracking: TrackingConsent? = nil
    ) -> EmailRegistrationOptions {
        return EmailRegistrationOptions(
            transactionalOptedIn: transactionalOptedIn,
            commercialOptedIn: commercialOptedIn,
            properties: properties,
            openTracking: openTracking,
            clickTracking: clickTracking
        )
    }

    /// Returns an Email registration options.
    /// - Parameter transactionalOptedIn: The transactional opted-in date.
    /// - Parameter properties: The properties. They must be JSON serializable.
    /// - Parameter doubleOptIn: The double opt-in value
    /// - Parameter openTracking: The open tracking consent, or nil to send none.
    /// - Parameter clickTracking: The click tracking consent, or nil to send none.
    /// - Returns: An Email registration options.
    public static func options(
        transactionalOptedIn: Date?,
        properties: [String: Any]?,
        doubleOptIn: Bool,
        openTracking: TrackingConsent? = nil,
        clickTracking: TrackingConsent? = nil
    ) -> EmailRegistrationOptions {
        return EmailRegistrationOptions(
            transactionalOptedIn: transactionalOptedIn,
            properties: properties,
            doubleOptIn: doubleOptIn,
            openTracking: openTracking,
            clickTracking: clickTracking
        )
    }

    /// Returns an Email registration options.
    /// - Parameter properties: The properties. They must be JSON serializable.
    /// - Parameter doubleOptIn: The double opt-in value
    /// - Parameter openTracking: The open tracking consent, or nil to send none.
    /// - Parameter clickTracking: The click tracking consent, or nil to send none.
    /// - Returns: An Email registration options.
    public static func options(
        properties: [String: Any]?,
        doubleOptIn: Bool,
        openTracking: TrackingConsent? = nil,
        clickTracking: TrackingConsent? = nil
    ) -> EmailRegistrationOptions {
        return EmailRegistrationOptions(
            transactionalOptedIn: nil,
            properties: properties,
            doubleOptIn: doubleOptIn,
            openTracking: openTracking,
            clickTracking: clickTracking
        )
    }

    enum CodingKeys: String, CodingKey {
        case transactionalOptedIn
        case commercialOptedIn
        case properties = "properties"
        case doubleOptIn
        case openTrackingOptedIn
        case openTrackingOptedOut
        case clickTrackingOptedIn
        case clickTrackingOptedOut
    }


    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.transactionalOptedIn = try container.decodeIfPresent(Date.self, forKey: .transactionalOptedIn)
        self.commercialOptedIn = try container.decodeIfPresent(Date.self, forKey: .commercialOptedIn)


        self.doubleOptIn = try container.decode(Bool.self, forKey: .doubleOptIn)
        self.openTrackingOptedIn = try container.decodeIfPresent(Date.self, forKey: .openTrackingOptedIn)
        self.openTrackingOptedOut = try container.decodeIfPresent(Date.self, forKey: .openTrackingOptedOut)
        self.clickTrackingOptedIn = try container.decodeIfPresent(Date.self, forKey: .clickTrackingOptedIn)
        self.clickTrackingOptedOut = try container.decodeIfPresent(Date.self, forKey: .clickTrackingOptedOut)

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
    private struct JsonValue: Decodable {
        let jsonEncodedValue: String?
    }
}

fileprivate extension EmailRegistrationOptions.TrackingConsent {
    var optedInDate: Date? {
        guard case .optedIn(let date) = self else { return nil }
        return date
    }

    var optedOutDate: Date? {
        guard case .optedOut(let date) = self else { return nil }
        return date
    }
}
