/* Copyright Airship and Contributors */

import Foundation

protocol MeteredUsageAPIClientProtocol: Sendable {
    func uploadEvents(
        _ events: [AirshipMeteredUsageEvent],
        channelID: String?
    ) async throws -> AirshipHTTPResponse<Void>
}


final class MeteredUsageAPIClient : MeteredUsageAPIClientProtocol {
    private let config: RuntimeConfig
    private let session: AirshipRequestSession

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom({ date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(
                AirshipDateFormatter.string(fromDate: date, format: .isoDelimitter)
            )
        })
        return encoder
    }()


    init(config: RuntimeConfig, session: AirshipRequestSession) {
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
        _ events: [AirshipMeteredUsageEvent], 
        channelID: String?
    ) async throws -> AirshipHTTPResponse<Void> {
        guard let meteredUsageURL = config.meteredUsageURL else {
            throw AirshipErrors.error("Missing metered usage URL")
        }

        var headers: [String: String] = [
            "X-UA-Lib-Version": AirshipVersion.version,
            "X-UA-Device-Family": "ios",
            "Content-Type": "application/json",
            "Accept":  "application/vnd.urbanairship+json; version=3;"
        ]

        if let channelID = channelID {
            headers["X-UA-Channel-ID"] = channelID
        }

        let body = try encoder.encode(RequestBody(usage: events))

        let request = AirshipRequest(
            url: URL(string: "\(meteredUsageURL)/api/metered-usage"),
            headers: headers,
            method: "POST",
            auth: .generatedAppToken,
            body: body
        )

        AirshipLogger.trace("Sending usage: \(events), request: \(request)")

        // Perform the upload
        let result = try await self.session.performHTTPRequest(request)
        AirshipLogger.debug("Usage result: \(result)")

        return result
    }


    fileprivate struct RequestBody: Encodable {
        let usage: [AirshipMeteredUsageEvent]
    }
}
