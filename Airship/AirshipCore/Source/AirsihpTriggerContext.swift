/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
public struct AirshipTriggerContext: Encodable, Sendable, Equatable {
    let type: String
    let goal: Double
    let event: AirshipJSON
}
