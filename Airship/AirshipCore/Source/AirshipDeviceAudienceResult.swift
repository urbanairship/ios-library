/* Copyright Airship and Contributors */

/// NOTE: For internal use only. :nodoc:
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
