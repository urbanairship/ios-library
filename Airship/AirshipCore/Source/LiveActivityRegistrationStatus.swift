/* Copyright Airship and Contributors */

import Foundation

/// Airship live activity registration status.
public enum LiveActivityRegistrationStatus: String, Codable, Sendable {
    /// The live activity is either waiting for a token to be generated and/or waiting for its registration to be sent
    /// to Airship.
    case pending

    /// The live activity is registered with Airship and is now able to be updated through APNS.
    case registered

    /// The live activity is either no longer updatable, been replaced with another live activity using the same name,
    /// or is not actively being tracked by Airship.
    case unknown
}
