/* Copyright Airship and Contributors */

import Foundation

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public struct AirshipDeviceAudienceResult: Sendable, Codable, Equatable {
    public var isMatch: Bool
    public var reportingMetadata: [AirshipJSON]?

    init(isMatch: Bool, reportingMetadata: [AirshipJSON]? = nil) {
        self.isMatch = isMatch
        self.reportingMetadata = reportingMetadata
    }

    mutating func negate() {
        isMatch = !isMatch
    }

    public static let match: AirshipDeviceAudienceResult = .init(isMatch: true)
    public static let miss: AirshipDeviceAudienceResult = .init(isMatch: false)
}
