/* Copyright Airship and Contributors */

import Foundation

/**
 * Channel type
 */
@objc(UAChannelType)
public enum ChannelType : Int, Codable, CustomStringConvertible {
    
    /**
     * Email channel
     */
    case email
    
    /**
     * SMS channel
     */
    case sms
    
    /**
     * Open channel
     */
    case open
    
    /// The string value of the channel type
    /// - Returns: The string value of the channel type
    var stringValue: String {
        switch self {
        case .email:
            return "email"
        case .sms:
            return "sms"
        case .open:
            return "open"
        }
    }
    
    /// Returns a channel type from a string.
    /// - Parameter value: The string value
    /// - Returns: A channel type.
    static func fromString(_ value: String) throws -> ChannelType {
        switch value {
        case "email":
            return .email
        case "sms":
            return .sms
        case "open":
            return .open
        default:
            throw AirshipErrors.error("invalid channel type \(value)")
        }
    }

    public var description: String {
        return stringValue
    }
}
