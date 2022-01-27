/* Copyright Airship and Contributors */

import Foundation


/**
 * Channel scope.
 */
@objc(UAChannelScope)
public enum ChannelScope: Int, Codable {
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
}
