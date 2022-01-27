/* Copyright Airship and Contributors */

import Foundation


/**
 * Channel scope.
 */
@objc(UAChannelScope)
public enum ChannelScope: Int, Codable, CustomStringConvertible {
    /**
     * App channels - amazon, android, iOS
     */
    case app
    
    /**
     * Web channels
     */
    case web
    
    /**
     * Email channels
     */
    case email
    
    /**
     * SMS channels
     */
    case sms
    
    
    var scopeString: String {
        switch self {
        case .sms:
            return "sms"
        case .email:
            return "email"
        case .app:
            return "app"
        case .web:
            return "web"
        }
    }
    
    static func fromString(_ scopeString: String) throws -> ChannelScope {
        switch scopeString {
        case "sms":
            return .sms
        case "email":
            return .email
        case "app":
            return .app
        case "web":
            return .web
        default:
            throw AirshipErrors.error("invalid scope \(scopeString)")
        }
    }
    
    public var description: String {
        return scopeString
    }
}
