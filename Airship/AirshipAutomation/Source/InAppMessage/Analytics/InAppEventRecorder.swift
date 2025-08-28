/* Copyright Airship and Contributors */



#if canImport(AirshipCore)
import AirshipCore
#endif

struct InAppEventData {
    let event: any InAppEvent
    let context: InAppEventContext?
    let source: InAppEventSource
    let messageID: InAppEventMessageID
    let renderedLocale: AirshipJSON?
}

protocol InAppEventRecorderProtocol: Sendable {
    func recordEvent(inAppEventData: InAppEventData)
    func recordImpressionEvent(_ event: AirshipMeteredUsageEvent)
}

struct InAppEventRecorder: InAppEventRecorderProtocol {
    private let airshipAnalytics: any InternalAnalyticsProtocol
    private let meteredUsage: any AirshipMeteredUsageProtocol

    init(airshipAnalytics: any InternalAnalyticsProtocol, meteredUsage: any AirshipMeteredUsageProtocol) {
        self.airshipAnalytics = airshipAnalytics
        self.meteredUsage = meteredUsage
    }

    func recordEvent(inAppEventData: InAppEventData) {
        let eventBody = EventBody(
            identifier: inAppEventData.messageID,
            source: inAppEventData.source,
            context: inAppEventData.context,
            conversionSendID: airshipAnalytics.conversionSendID,
            conversionPushMetadata: airshipAnalytics.conversionPushMetadata,
            renderedLocale: inAppEventData.renderedLocale,
            baseData: inAppEventData.event.data
        )

        do {
            airshipAnalytics.recordEvent(
                AirshipEvent(
                    eventType: inAppEventData.event.name,
                    eventData: try AirshipJSON.wrap(eventBody)
                )
            )
        } catch {
            AirshipLogger.error("Failed to add event \(inAppEventData) error \(error)")
        }
    }

    func recordImpressionEvent(_ event: AirshipMeteredUsageEvent) {
        Task { [meteredUsage] in
            do {
                try await meteredUsage.addEvent(event)
            } catch {
                AirshipLogger.error("Failed to record impression: \(error)")
            }
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

    func encode(to encoder: any Encoder) throws {
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
