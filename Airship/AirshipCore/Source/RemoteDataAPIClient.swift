/* Copyright Airship and Contributors */



protocol RemoteDataAPIClientProtocol: Sendable {
    func fetchRemoteData(
        url: URL,
        auth: AirshipRequestAuth,
        lastModified: String?,
        remoteDataInfoBlock: @Sendable @escaping (String?) throws -> RemoteDataInfo
    ) async throws -> AirshipHTTPResponse<RemoteDataResult>
}

final class RemoteDataAPIClient: RemoteDataAPIClientProtocol {
    private let session: any AirshipRequestSession
    private let config: RuntimeConfig

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom({ (decoder) -> Date in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)

            guard let date = AirshipDateFormatter.date(fromISOString: dateStr) else {
                throw AirshipErrors.error("Invalid date \(dateStr)")
            }
            return date
        })
        return decoder
    }

    init(config: RuntimeConfig, session: any AirshipRequestSession) {
        self.config = config
        self.session = session
    }

    convenience init(config: RuntimeConfig) {
        self.init(config: config, session: config.requestSession)
    }

    func fetchRemoteData(
        url: URL,
        auth: AirshipRequestAuth,
        lastModified: String?,
        remoteDataInfoBlock: @Sendable @escaping (String?) throws -> RemoteDataInfo
    ) async throws -> AirshipHTTPResponse<RemoteDataResult> {
        var headers: [String: String] = [
            "X-UA-Appkey": self.config.appCredentials.appKey,
            "Accept": "application/vnd.urbanairship+json; version=3;"
        ]

        if let lastModified = lastModified {
            headers["If-Modified-Since"] = lastModified
        }

        let request = AirshipRequest(
            url: url,
            headers: headers,
            method: "GET",
            auth: auth
        )

        AirshipLogger.debug("Request to update remote data: \(request)")

        return try await self.session.performHTTPRequest(request) { data, response in
            
            AirshipLogger.debug("Fetching remote data finished with response: \(response)")
            
            guard response.statusCode == 200, let data = data else {
                return nil
            }

            let remoteDataResponse = try self.decoder.decode(RemoteDataResponse.self, from: data)
            let remoteDataInfo = try remoteDataInfoBlock(response.value(forHTTPHeaderField: "Last-Modified"))

            let payloads = (remoteDataResponse.payloads ?? [])
                .map { payload in
                    RemoteDataPayload(
                        type: payload.type,
                        timestamp: payload.timestamp,
                        data: payload.data,
                        remoteDataInfo: remoteDataInfo
                    )
                }
            return RemoteDataResult(payloads: payloads, remoteDataInfo: remoteDataInfo)
        }
    }
}

struct RemoteDataResult: Equatable {
    let payloads: [RemoteDataPayload]
    let remoteDataInfo: RemoteDataInfo
}

fileprivate struct RemoteDataResponse: Codable {
    let payloads: [Payload]?
    
    struct Payload: Codable {
        let type: String
        let timestamp: Date
        let data: AirshipJSON
    }
}

