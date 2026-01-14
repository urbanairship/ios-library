/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
public struct ThomasLayoutEventData {
    let event: any ThomasLayoutEvent
    let context: ThomasLayoutEventContext?
    let source: ThomasLayoutEventSource
    let messageID: ThomasLayoutEventMessageID
    let renderedLocale: AirshipJSON?
    
    public init(
        event: any ThomasLayoutEvent,
        context: ThomasLayoutEventContext?,
        source: ThomasLayoutEventSource,
        messageID: ThomasLayoutEventMessageID,
        renderedLocale: AirshipJSON?
    ) {
        self.event = event
        self.context = context
        self.source = source
        self.messageID = messageID
        self.renderedLocale = renderedLocale
    }
}

/// NOTE: For internal use only. :nodoc:
public protocol ThomasLayoutEventRecorderProtocol: Sendable {
    func recordEvent(inAppEventData: ThomasLayoutEventData)
    func recordImpressionEvent(_ event: AirshipMeteredUsageEvent)
}

/// NOTE: For internal use only. :nodoc:
public struct ThomasLayoutEventRecorder: ThomasLayoutEventRecorderProtocol {
    private let airshipAnalytics: any InternalAirshipAnalytics
    private let meteredUsage: any AirshipMeteredUsage

    public init(airshipAnalytics: any InternalAirshipAnalytics, meteredUsage: any AirshipMeteredUsage) {
        self.airshipAnalytics = airshipAnalytics
        self.meteredUsage = meteredUsage
    }

    public func recordEvent(inAppEventData: ThomasLayoutEventData) {
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

    public func recordImpressionEvent(_ event: AirshipMeteredUsageEvent) {
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
    var identifier: ThomasLayoutEventMessageID
    var source: ThomasLayoutEventSource
    var context: ThomasLayoutEventContext?
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
