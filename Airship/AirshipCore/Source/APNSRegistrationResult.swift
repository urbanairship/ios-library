// Copyright Airship and Contributors

import Foundation

/// The result of an APNs registration.
public enum APNSRegistrationResult: Sendable {
    /// Registration was successful and a new device token was received.
    case success(deviceToken: String)

    /// Registration failed.
    case failure(error: any Error)
}
