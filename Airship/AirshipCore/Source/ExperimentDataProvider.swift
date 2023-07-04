/* Copyright Airship and Contributors */

import Foundation

// NOTE: For internal use only. :nodoc:
@objc(UAExperimentDataProvider)
public protocol ExperimentDataProvider {
    func evaluateExperiments(info: MessageInfo, contactID: String?) async throws -> ExperimentResult
}

// NOTE: For internal use only. :nodoc:
@objc
public final class MessageInfo: NSObject {
    let messageType: String
    
    init(messageType: String) {
        self.messageType = messageType
    }
}

// NOTE: For internal use only. :nodoc:
@objc
public final class ExperimentResult: NSObject {
    @objc public let channelID: String
    @objc public let contactID: String

    @objc public let isMatch: Bool
    public let evaluatedExperimentsReportingData: [AirshipJSON]

    @objc(evaluatedExperimentsReportingData)
    public var _evaluatedExperimentsReportingData: [Any] {
        return evaluatedExperimentsReportingData.compactMap { $0.unWrap() }
    }

    init(channelID: String, contactID: String, isMatch: Bool, evaluatedExperimentsReportingData: [AirshipJSON]) {
        self.channelID = channelID
        self.contactID = contactID
        self.isMatch = isMatch
        self.evaluatedExperimentsReportingData = evaluatedExperimentsReportingData
    }
}
