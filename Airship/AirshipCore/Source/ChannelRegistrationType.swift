/* Copyright Airship and Contributors */

import Foundation

/// Represents the channel registration state
public enum ChannelRegistrationState: Sendable {
    
    // Failed
    case failed
    
    // Succeed
    case succeed(ChannelRegistrationType)
}


/// Represents the optin/optout channel through the SDK.
public enum ChannelRegistrationType: Sendable {
    
    // Optin channel
    case optIn(AssociatedChannelType)
    
    // Optout channel
    case optOut(String)
}
