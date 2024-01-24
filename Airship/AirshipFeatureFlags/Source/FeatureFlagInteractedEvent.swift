/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#endif

import Foundation


/// - Note: For Internal use only :nodoc:
public class FeatureFlagInteractedEvent: NSObject, AirshipEvent {
    @objc
    public let eventType: String  = "feature_flag_interaction"

    public let data: [AnyHashable: Any]

    @objc
    public let priority: EventPriority  = .normal

    init(
        flag: FeatureFlag
    ) throws {
        self.data = try FeatureFlagInteractedEvent.makeData(flag: flag)
        super.init()
    }
    
    public var name: String? {
        return self.data[Key.name] as? String
    }

    class func makeData(flag: FeatureFlag) throws -> [AnyHashable : Any] {
        guard let reportingInfo = flag.reportingInfo else {
            throw AirshipErrors.error("Missing reportingInfo")
        }

        var data: [AnyHashable: Any] = [
            Key.name: flag.name,
            Key.metadata: reportingInfo.reportingMetadata,
            Key.eligible: flag.isEligible
        ]

        var deviceInfo: [String : String] = [:]
        deviceInfo["channel_id"] = reportingInfo.channelID
        deviceInfo["contact_id"] = reportingInfo.contactID

        if (!deviceInfo.isEmpty) {
            data[Key.device] = deviceInfo
        }

        return data
    }
    
    private enum Key {
        static let name = "flag_name"
        static let metadata = "reporting_metadata"
        static let eligible = "eligible"
        static let device = "device"
    }
}


