/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif


protocol FeatureFlagAnalyticsProtocol: Sendable {
    func trackInteraction(flag: FeatureFlag)
}

final class FeatureFlagAnalytics: FeatureFlagAnalyticsProtocol {
    private let airshipAnalytics: any InternalAnalyticsProtocol

    private enum FlagKeys {
        static let name = "flag_name"
        static let metadata = "reporting_metadata"
        static let supersededMetadata = "superseded_reporting_metadata"
        static let eligible = "eligible"
        static let device = "device"
    }

    private enum DeviceKeys {
        static let channelID = "channel_id"
        static let contactID = "contact_id"
    }

    init(
        airshipAnalytics: any InternalAnalyticsProtocol
    ) {
        self.airshipAnalytics = airshipAnalytics
    }

    func trackInteraction(flag: FeatureFlag) {
        guard flag.exists else { return }

        guard let reportingInfo = flag.reportingInfo else {
            AirshipLogger.error("Missing reportingInfo, unable to track flag interaction \(flag)")
            return
        }

        let eventBody = AirshipJSON.makeObject{ object in
            object.set(string: flag.name, key: FlagKeys.name)
            object.set(json: reportingInfo.reportingMetadata, key: FlagKeys.metadata)
            object.set(bool: flag.isEligible, key: FlagKeys.eligible)
            
            if let superseded = reportingInfo.supersededReportingMetadata {
                object.set(json: .array(superseded), key: FlagKeys.supersededMetadata)
            }

            let device = AirshipJSON.makeObject { object in
                object.set(string: reportingInfo.channelID, key: DeviceKeys.channelID)
                object.set(string: reportingInfo.contactID, key: DeviceKeys.contactID)
            }

            if (device.object?.isEmpty != true) {
                object.set(json: device, key: FlagKeys.device)
            }
        }

        let airshipEvent = AirshipEvent(
            eventType: .featureFlagInteraction,
            eventData: eventBody
        )

        airshipAnalytics.recordEvent(airshipEvent)
    }
}


