/* Copyright Airship and Contributors */

@_spi(AirshipInternal) import AirshipSceneRenderer
@_spi(AirshipInternal) import AirshipBasement
import Foundation
public import AirshipCore

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public struct ThomasLayoutEventData: Sendable {
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

extension ThomasLayoutEventData: CustomStringConvertible {
    public var description: String {
        "ThomasLayoutEventData(eventType: \(event.name.reportingName), messageID: \(messageID.identifier), source: \(source.rawValue))"
    }
}

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public protocol ThomasLayoutEventRecorderProtocol: Sendable {
    func recordEvent(thomasLayoutEventData: ThomasLayoutEventData)
    func recordImpressionEvent(_ event: AirshipMeteredUsageEvent)
}

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public struct ThomasLayoutEventRecorder: ThomasLayoutEventRecorderProtocol {
    private let airshipAnalytics: any InternalAirshipAnalytics
    private let meteredUsage: any AirshipMeteredUsage

    public init(
        airshipAnalytics: any InternalAirshipAnalytics,
        meteredUsage: any AirshipMeteredUsage
    ) {
        self.airshipAnalytics = airshipAnalytics
        self.meteredUsage = meteredUsage
    }

    public func recordEvent(thomasLayoutEventData: ThomasLayoutEventData) {
        let eventBody = EventBody(
            identifier: thomasLayoutEventData.messageID,
            source: thomasLayoutEventData.source,
            context: thomasLayoutEventData.context,
            conversionSendID: airshipAnalytics.conversionSendID,
            conversionPushMetadata: airshipAnalytics.conversionPushMetadata,
            renderedLocale: thomasLayoutEventData.renderedLocale,
            baseData: thomasLayoutEventData.event.data
        )

        do {
            airshipAnalytics.recordEvent(
                AirshipEvent(
                    eventType: thomasLayoutEventData.event.name,
                    eventData: try AirshipJSON.wrap(eventBody)
                )
            )
        } catch {
            AirshipLogger.error("Failed to add native layout event \(thomasLayoutEventData): \(error)")
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
