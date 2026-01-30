/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
public struct ThomasLayoutResolutionEvent: ThomasLayoutEvent {

    public let name: EventType = EventType.inAppResolution
    public let data: (any Sendable & Encodable)?

    private init(data: any Sendable & Encodable) {
        self.data = data
    }

    public static func buttonTap(
        identifier: String,
        description: String,
        displayTime: TimeInterval
    ) -> ThomasLayoutResolutionEvent {
        return ThomasLayoutResolutionEvent(
            data: ResolutionData(
                resolutionType: .buttonTap(
                    identifier: identifier,
                    description: description
                ),
                displayTime: displayTime
            )
        )
    }

    public static func messageTap(displayTime: TimeInterval) -> ThomasLayoutResolutionEvent {
        return ThomasLayoutResolutionEvent(
            data: ResolutionData(
                resolutionType: .messageTap,
                displayTime: displayTime
            )
        )
    }

    public static func userDismissed(displayTime: TimeInterval) -> ThomasLayoutResolutionEvent {
        return ThomasLayoutResolutionEvent(
            data: ResolutionData(
                resolutionType: .userDismissed,
                displayTime: displayTime
            )
        )
    }

    public static func timedOut(displayTime: TimeInterval) -> ThomasLayoutResolutionEvent {
        return ThomasLayoutResolutionEvent(
            data: ResolutionData(
                resolutionType: .timedOut,
                displayTime: displayTime
            )

        )
    }

    public static func interrupted() -> ThomasLayoutResolutionEvent {
        return ThomasLayoutResolutionEvent(
            data: ResolutionData(
                resolutionType: .interrupted,
                displayTime: 0.0
            )
        )
    }

    public static func control(
        experimentResult: ExperimentResult
    ) -> ThomasLayoutResolutionEvent {
        return ThomasLayoutResolutionEvent(
            data: ResolutionData(
                resolutionType: .control,
                displayTime: 0.0,
                device: DeviceInfo(
                    channel: experimentResult.channelID,
                    contact: experimentResult.contactID
                )
            )
        )
    }

    public static func audienceExcluded() -> ThomasLayoutResolutionEvent {
        return ThomasLayoutResolutionEvent(
            data: ResolutionData(
                resolutionType: .audienceCheckExcluded,
                displayTime: 0.0
            )
        )
    }

    private struct DeviceInfo: Encodable, Sendable {
        var channel: String?
        var contact: String?

        enum CodingKeys: String, CodingKey {
            case channel = "channel_id"
            case contact = "contact_id"
        }
    }

    private struct ResolutionData: Encodable, Sendable {

        enum ResolutionType {
            case buttonTap(identifier: String, description: String)
            case messageTap
            case userDismissed
            case timedOut
            case interrupted
            case control
            case audienceCheckExcluded
        }

        let resolutionType: ResolutionType
        let displayTime: TimeInterval
        var device: DeviceInfo?

        enum CodingKeys: String, CodingKey {
            case resolutionType = "type"
            case displayTime = "display_time"
            case buttonID = "button_id"
            case buttonDescription = "button_description"
        }

        enum ContainerCodingKeys: String, CodingKey {
            case resolution = "resolution"
            case device = "device"
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: ContainerCodingKeys.self)
            var resolution = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .resolution)

            try resolution.encode(
                String(format: "%.2f", displayTime),
                forKey: .displayTime
            )

            try container.encodeIfPresent(self.device, forKey: .device)

            switch (self.resolutionType) {
            case .buttonTap(let identifier, let description):
                try resolution.encode("button_click", forKey: .resolutionType)
                try resolution.encode(identifier, forKey: .buttonID)
                try resolution.encode(description, forKey: .buttonDescription)

            case .messageTap:
                try resolution.encode("message_click", forKey: .resolutionType)
            case .userDismissed:
                try resolution.encode("user_dismissed", forKey: .resolutionType)
            case .timedOut:
                try resolution.encode("timed_out", forKey: .resolutionType)
            case .interrupted:
                try resolution.encode("interrupted", forKey: .resolutionType)
            case .control:
                try resolution.encode("control", forKey: .resolutionType)
            case .audienceCheckExcluded:
                try resolution.encode("audience_check_excluded", forKey: .resolutionType)
            }
        }
    }
}
