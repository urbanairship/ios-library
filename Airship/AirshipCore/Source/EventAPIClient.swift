/* Copyright Airship and Contributors */
import Foundation

protocol EventAPIClientProtocol: Sendable {
    func uploadEvents(
        _ events: [AirshipEventData],
        channelID: String,
        headers: [String: String]
    ) async throws -> AirshipHTTPResponse<EventUploadTuningInfo>
}

final class EventAPIClient: EventAPIClientProtocol {
    private let config: RuntimeConfig
    private let session: any AirshipRequestSession

    init(config: RuntimeConfig, session: any AirshipRequestSession) {
        self.config = config
        self.session = session
    }

    convenience init(config: RuntimeConfig) {
        self.init(
            config: config,
            session: config.requestSession
        )
    }

    func uploadEvents(
        _ events: [AirshipEventData],
        channelID: String,
        headers: [String: String]
    ) async throws -> AirshipHTTPResponse<EventUploadTuningInfo> {

        guard let analyticsURL = config.analyticsURL else {
            throw AirshipErrors.error("The analyticsURL is nil")
        }

        var allHeaders = headers
        allHeaders["X-UA-Sent-At"] = "\(Date().timeIntervalSince1970)"
        allHeaders["Content-Type"] = "application/json"

        let request = AirshipRequest(
            url: URL(string: "\(analyticsURL)/warp9/"),
            headers: allHeaders,
            method: "POST",
            auth: .channelAuthToken(identifier: channelID),
            body: try self.requestBody(fromEvents: events),
            compressBody: true
        )

        AirshipLogger.trace("Sending to server: \(config.analyticsURL ?? "")")
        AirshipLogger.trace("Sending analytics headers: \(allHeaders)")
        AirshipLogger.trace("Sending analytics events: \(events)")

        // Perform the upload
        return try await self.session.performHTTPRequest(request) { _, response in
            
            AirshipLogger.debug("Upload event finished with response: \(response)")
            
            return EventUploadTuningInfo(
                maxTotalStoreSizeKB: response.unsignedInt(
                    forHeader: "X-UA-Max-Total"
                ),
                maxBatchSizeKB: response.unsignedInt(
                    forHeader: "X-UA-Max-Batch"
                ),
                minBatchInterval: response.double(
                    forHeader: "X-UA-Min-Batch-Interval"
                )
            )
        }
    }

    private func requestBody(fromEvents events: [AirshipEventData]) throws -> Data {
        let preparedEvents: [[String: Any]] = events.compactMap { eventData in
            var eventBody: [String: Any] = [:]
            eventBody["event_id"] =  eventData.id
            eventBody["time"] = String(
                format: "%f",
                eventData.date.timeIntervalSince1970
            )
            eventBody["type"] = eventData.type.reportingName
            
        
            guard
                var data = eventData.body.unWrap() as? [String: Any]
            else {
                AirshipLogger.error("Failed to deserialize event body \(eventData)")
                return nil
            }
            
            data["session_id"] = eventData.sessionID
            eventBody["data"] = data
            return eventBody
        }

        return try AirshipJSONUtils.data(preparedEvents, options: [])
    }
}


fileprivate extension HTTPURLResponse {
    func double(forHeader header: String) -> Double? {
        guard let value = self.allHeaderFields[header] else {
            return nil
        }

        if let value = value as? Double {
            return value
        }

        if let value = value as? String {
            return Double(value)
        }

        if let value = value as? NSNumber {
            return value.doubleValue
        }

        return nil
    }

    func unsignedInt(forHeader header: String) -> UInt? {
        guard let value = self.allHeaderFields[header] else {
            return nil
        }

        if let value = value as? UInt {
            return value
        }

        if let value = value as? String {
            return UInt(value)
        }

        if let value = value as? NSNumber {
            return value.uintValue
        }

        return nil
    }
}
