/* Copyright Airship and Contributors */


import os

/// Represents the possible log privacy level.
public enum AirshipLogPrivacyLevel: String, Sendable, Decodable {
    /**
     * Private log privacy level. Set by default.
     */
    case `private` = "private"

    /**
     * Public log privacy level. Logs publicly when set via the AirshipConfig.
     */
    case `public` = "public"

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        do {
            let stringValue = try container.decode(String.self)
            switch(stringValue) {
            case "private":
                self = .private
            case "public":
                self = .public
            default:
                self = .private
            }
        } catch {
            guard let intValue = try? container.decode(Int.self) else {
                throw error
            }
            
            switch(intValue) {
                
            case 0:
                self = .private
            case 1:
                self = .public
            default:
                throw error
            }
        }
    }
}
