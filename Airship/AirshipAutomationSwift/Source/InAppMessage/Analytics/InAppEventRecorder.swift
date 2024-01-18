/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

struct InAppEventData {
    let event: InAppEvent
    let context: InAppEventContext?
    let source: InAppEventSource
    let messageID: InAppEventMessageID
    let renderedLocale: AirshipJSON?
}

protocol InAppEventRecorderProtocol: Sendable {
    func recordEvent(inAppEventData: InAppEventData)
}

struct InAppEventRecorder: InAppEventRecorderProtocol {
    private let analytics: AnalyticsProtocol

    init(analytics: AnalyticsProtocol) {
        self.analytics = analytics
    }

    func recordEvent(inAppEventData: InAppEventData) {
        let eventBody = EventBody(
            identifier: inAppEventData.messageID,
            source: inAppEventData.source,
            context: inAppEventData.context,
            conversionSendID: analytics.conversionSendID,
            conversionPushMetadata: analytics.conversionPushMetadata,
            renderedLocale: inAppEventData.renderedLocale,
            baseData: inAppEventData.event.data
        )

        do {
            guard let data = try AirshipJSON.wrap(eventBody).unWrap() as? [AnyHashable: Any] else {
                throw AirshipErrors.error("failed to wrap data")
            }

            analytics.addEvent(
                Event(data: data, eventType: inAppEventData.event.name)
            )
        } catch {
            AirshipLogger.error("Failed to add event \(inAppEventData) error \(error)")
        }

    }
}

fileprivate struct EventBody: Encodable, Sendable {
    var identifier: InAppEventMessageID
    var source: InAppEventSource
    var context: InAppEventContext?
    var conversionSendID: String?
    var conversionPushMetadata: String?
    var renderedLocale: AirshipJSON?
    var baseData: (any Encodable&Sendable)?

    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case source
        case context
        case conversionSendID = "conversion_send_id"
        case conversionPushMetadata = "conversion_metadata"
        case renderedLocale = "rendered_locale"
        case deviceInfo = "device"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Self.CodingKeys.self)
        try container.encode(self.identifier, forKey: Self.CodingKeys.identifier)
        try container.encode(self.source, forKey: Self.CodingKeys.source)
        try container.encodeIfPresent(self.context, forKey: Self.CodingKeys.context)
        try container.encodeIfPresent(self.conversionSendID, forKey: Self.CodingKeys.conversionSendID)
        try container.encodeIfPresent(self.conversionPushMetadata, forKey: Self.CodingKeys.conversionPushMetadata)
        try container.encodeIfPresent(self.renderedLocale, forKey: Self.CodingKeys.renderedLocale)
        try self.baseData?.encode(to: encoder)
    }
}

fileprivate final class Event: NSObject, AirshipEvent {
    let data: [AnyHashable : Any]
    let eventType: String
    let priority: EventPriority = .normal
    init(data: [AnyHashable : Any], eventType: String) {
        self.data = data
        self.eventType = eventType
    }
}
