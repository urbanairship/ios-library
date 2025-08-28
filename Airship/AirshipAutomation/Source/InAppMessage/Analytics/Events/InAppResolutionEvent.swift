/* Copyright Airship and Contributors */



#if canImport(AirshipCore)
import AirshipCore
#endif

struct InAppResolutionEvent: InAppEvent {

    let name = EventType.inAppResolution
    let data: (any Sendable & Encodable)?

    private init(data: any Sendable & Encodable) {
        self.data = data
    }

    static func buttonTap(
        identifier: String,
        description: String,
        displayTime: TimeInterval
    ) -> InAppResolutionEvent {
        return InAppResolutionEvent(
            data: ResolutionData(
                resolutionType: .buttonTap(
                    identifier: identifier,
                    description: description
                ),
                displayTime: displayTime
            )
        )
    }

    static func messageTap(displayTime: TimeInterval) -> InAppResolutionEvent {
        return InAppResolutionEvent(
            data: ResolutionData(
                resolutionType: .messageTap,
                displayTime: displayTime
            )
        )
    }

    static func userDismissed(displayTime: TimeInterval) -> InAppResolutionEvent {
        return InAppResolutionEvent(
            data: ResolutionData(
                resolutionType: .userDismissed,
                displayTime: displayTime
            )
        )
    }

    static func timedOut(displayTime: TimeInterval) -> InAppResolutionEvent {
        return InAppResolutionEvent(
            data: ResolutionData(
                resolutionType: .timedOut,
                displayTime: displayTime
            )

        )
    }

    static func interrupted() -> InAppResolutionEvent {
        return InAppResolutionEvent(
            data: ResolutionData(
                resolutionType: .interrupted,
                displayTime: 0.0
            )
        )
    }

    static func control(
        experimentResult: ExperimentResult
    ) -> InAppResolutionEvent {
        return InAppResolutionEvent(
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

    static func audienceExcluded() -> InAppResolutionEvent {
        return InAppResolutionEvent(
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
