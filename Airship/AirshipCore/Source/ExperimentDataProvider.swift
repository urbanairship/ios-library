/* Copyright Airship and Contributors */

import Foundation

// NOTE: For internal use only. :nodoc:
@objc(UAExperimentDataProvider)
public protocol ExperimentDataProvider {
    @objc
    func evaluateExperiments(info: MessageInfo, contactID: String?) async throws -> ExperimentResult
}

// NOTE: For internal use only. :nodoc:
@objc(UAExperimentMessageInfo)
public final class MessageInfo: NSObject {
    let messageType: String
    let campaigns: AirshipJSON?

    @objc
    public init(messageType: String, campaignsJSON: Any? = nil) {
        self.messageType = messageType
        self.campaigns = try? AirshipJSON.wrap(campaignsJSON)
    }

    public init(messageType: String, campaigns: AirshipJSON? = nil) {
        self.messageType = messageType
        self.campaigns = try? AirshipJSON.wrap(campaigns)
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? MessageInfo else {
            return false
        }
        
        return other.messageType == messageType
    }
}

// NOTE: For internal use only. :nodoc:
@objc(UAExperimentResult)
public final class ExperimentResult: NSObject, Codable {
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
    
    @objc
    public convenience init(channelId: String, contactId: String, isMatch: Bool, reportingMetadata: [Any]) {
        let metadata = reportingMetadata.compactMap({ try? AirshipJSON.wrap($0) })
        self.init(channelID: channelId, contactID: contactId, isMatch: isMatch, evaluatedExperimentsReportingData: metadata)
    }
    
    public override var description: String {
        return "ExperimentResult: channgeId: \(channelID), contactId: \(contactID), isMatch: \(isMatch), metadata: \(evaluatedExperimentsReportingData)"
    }
}

// Needed for IAA since it can't deal with codables until its rewritten in swift
extension PreferenceDataStore {
    @objc
    public func storeExperimentResult(_ experiment: ExperimentResult?, forKey key: String)  {
        self.setSafeCodable(experiment, forKey: key)
    }

    @objc
    public func experimentResult(forKey key: String) -> ExperimentResult? {
        return self.safeCodable(forKey: key)
    }
}
