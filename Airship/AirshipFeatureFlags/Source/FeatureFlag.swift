/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Feature flag
public struct FeatureFlag: Equatable, Sendable, Codable {

    /// The name of the flag
    public let name: String

    /// If the device is elegible or not for the flag.
    public let isEligible: Bool

    /// If the flag exists in the current flag listing or not
    public let exists: Bool

    /// Optional variables associated with the flag
    public let variables: AirshipJSON?

    let reportingInfo: ReportingInfo?

    init(
        name: String,
        isEligible: Bool,
        exists: Bool, 
        variables: AirshipJSON? = nil,
        reportingInfo: ReportingInfo? = nil
    ) {
        self.name = name
        self.isEligible = isEligible
        self.exists = exists
        self.variables = variables
        self.reportingInfo = reportingInfo
    }

    enum CodingKeys: String, CodingKey {
        case name
        case isEligible = "is_eligible"
        case exists
        case variables
        case reportingInfo = "_reporting_info"
    }

    struct ReportingInfo: Codable, Sendable, Equatable {
        // Reporting info
        let reportingMetadata: AirshipJSON

        // Evaluated contact ID
        let contactID: String?

        // Evaluated channel ID
        let channelID: String?

        init(reportingMetadata: AirshipJSON, contactID: String? = nil, channelID: String? = nil) {
            self.reportingMetadata = reportingMetadata
            self.contactID = contactID
            self.channelID = channelID
        }

        enum CodingKeys: String, CodingKey {
            case reportingMetadata = "reporting_metadata"
            case contactID = "contact_id"
            case channelID = "channel_id"
        }
    }
}



