/* Copyright Airship and Contributors */

import Foundation

import AirshipCore
@_spi(AirshipInternal) import AirshipScenes


protocol LegacyInAppAnalyticsProtocol: Sendable {
    func recordReplacedEvent(scheduleID: String, replacementID: String)
    func recordDirectOpenEvent(scheduleID: String)
}

struct LegacyInAppAnalytics : LegacyInAppAnalyticsProtocol {
    let recorder: any ThomasLayoutEventRecorderProtocol

    func recordReplacedEvent(scheduleID: String, replacementID: String) {
        recorder.recordEvent(
            thomasLayoutEventData: ThomasLayoutEventData(
                event: LegacyResolutionEvent.replaced(replacementID: replacementID),
                context: nil,
                source: .airship,
                messageID: .legacy(identifier: scheduleID),
                renderedLocale: nil
            )
        )
    }

    func recordDirectOpenEvent(scheduleID: String) {
        recorder.recordEvent(
            thomasLayoutEventData: ThomasLayoutEventData(
                event: LegacyResolutionEvent.directOpen(),
                context: nil,
                source: .airship,
                messageID: .legacy(identifier: scheduleID),
                renderedLocale: nil
            )
        )
    }
}

struct LegacyResolutionEvent : ThomasLayoutEvent {
    let name = AirshipEventType.inAppResolution

    let data: (any Encodable & Sendable)?

    private init(data: (any Encodable & Sendable)?) {
        self.data = data
    }

    static func replaced(replacementID: String) -> LegacyResolutionEvent {
        return LegacyResolutionEvent(
            data: LegacyResolutionBody(type: .replaced, replacementID: replacementID)
        )
    }

    static func directOpen() -> LegacyResolutionEvent {
        return LegacyResolutionEvent(
            data: LegacyResolutionBody(type: .directOpen)
        )
    }

    fileprivate enum LegacyResolutionType: String, Encodable {
        case replaced
        case directOpen = "direct_open"
    }

    fileprivate struct LegacyResolutionBody: Encodable {
        var type: LegacyResolutionType
        var replacementID: String?

        enum CodingKeys: String, CodingKey {
            case type
            case replacementID = "replacement_id"
        }
    }
}






