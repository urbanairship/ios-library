/* Copyright Airship and Contributors */

import Foundation

// NOTE: For internal use only. :nodoc:
@objc(UAExperimentDataProvider)
public protocol ExperimentDataProvider {
    func evaluateGlobalHoldouts(info: MessageInfo, contactId: String?) async -> ExperimentResult? 
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
    let channelId: String
    let contactId: String? // set if this experiment was evaluated with a contact id or not
    let experimentId: String
    let reportingMetadata: [String: String]
    
    init(channelId: String, contactId: String?, experimentId: String, reportingMetadata: [String : String]) {
        self.channelId = channelId
        self.contactId = contactId
        self.experimentId = experimentId
        self.reportingMetadata = reportingMetadata
    }
}
