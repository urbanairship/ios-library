/* Copyright Airship and Contributors */

import Foundation

/// Airship live activity registration status.
public enum LiveActivityRegistrationStatus: String, Codable, Sendable {
    /// The live activity is either waiting for a token to be generated and/or waiting for its registration to be sent
    /// to Airship.
    case pending

    /// The live activity is registered with Airship and is now able to be updated through APNS.
    case registered

    /// Airship is not actively tracking the live activity. Usually this means it has ended, been replaced
    /// with another activity using the same name, or was not tracked with Airship.
    case notTracked
}
