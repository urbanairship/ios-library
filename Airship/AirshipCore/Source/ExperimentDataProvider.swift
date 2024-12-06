/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
public protocol ExperimentDataProvider: Sendable {
    func evaluateExperiments(
        info: MessageInfo,
        deviceInfoProvider: any AudienceDeviceInfoProvider
    ) async throws -> ExperimentResult?
}

/// NOTE: For internal use only. :nodoc:
public struct MessageInfo: Equatable, Hashable {
    let messageType: String
    let campaigns: AirshipJSON?

    public init(messageType: String, campaigns: AirshipJSON? = nil) {
        self.messageType = messageType
        self.campaigns = try? AirshipJSON.wrap(campaigns)
    }
}

/// NOTE: For internal use only. :nodoc:
public struct ExperimentResult: Codable, Sendable, Hashable {
    public let channelID: String
    public let contactID: String
    public let isMatch: Bool
    public let reportingMetadata: [AirshipJSON]

    public init(channelID: String, contactID: String, isMatch: Bool, reportingMetadata: [AirshipJSON]) {
        self.channelID = channelID
        self.contactID = contactID
        self.isMatch = isMatch
        self.reportingMetadata = reportingMetadata
    }
}
