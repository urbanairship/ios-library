/* Copyright Airship and Contributors */

import Foundation

public enum OptinStatus: Sendable {
    case optIn
    case optOut
}

/// Airship channel optin status
public struct AirshipChannelOptinStatus: Sendable, Equatable {
    
    // The channel optin type
    public let type: ChannelType
    
    // The channel optin identifier
    public let id: String
    
    // The channel optin sender if exists
    public let sender: String?
    
    // The channel optin status
    public let status: OptinStatus
    
}
