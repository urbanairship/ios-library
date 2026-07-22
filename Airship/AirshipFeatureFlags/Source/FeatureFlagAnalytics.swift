/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipInternal) import AirshipBasement

@_spi(AirshipInternal) import AirshipCore


protocol FeatureFlagAnalyticsProtocol: Sendable {
    func trackInteraction(flag: FeatureFlag)
}

final class FeatureFlagAnalytics: FeatureFlagAnalyticsProtocol {
    private let airshipAnalytics: any InternalAirshipAnalytics

    private enum FlagKeys {
        static let name: String = "flag_name"
        static let metadata: String = "reporting_metadata"
        static let supersededMetadata: String = "superseded_reporting_metadata"
        static let eligible: String = "eligible"
        static let device: String = "device"
    }

    private enum DeviceKeys {
        static let channelID: String = "channel_id"
        static let contactID: String = "contact_id"
    }

    init(
        airshipAnalytics: any InternalAirshipAnalytics
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


