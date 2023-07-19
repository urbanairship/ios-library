/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif


/// Feature flag
public struct FeatureFlag: Equatable, Sendable, Codable {

    /// If the device is elegible or not for the flag.
    public let isEligible: Bool

    /// If the flag exists in the current flag listing or not
    public let exists: Bool

    /// Optional variables associated with the flag
    public let variables: AirshipJSON?

    enum CodingKeys: String, CodingKey {
        case isEligible = "is_eligible"
        case exists
        case variables
    }
}
