/* Copyright Airship and Contributors */

protocol RemoteDataAPIClientProtocol {
    func fetchRemoteData(
        locale: Locale,
        randomValue: Int,
        lastModified: String?
    ) async throws -> AirshipHTTPResponse<RemoteDataResponse>

    func metadata(locale: Locale, randomValue: Int, lastModified: String?)
        -> [AnyHashable: Any]
}

class RemoteDataAPIClient: RemoteDataAPIClientProtocol {
    private static let urlMetadataKey = "url"
    private static let lastModifiedMetadataKey = "last_modified"

    private let path = "api/remote-data/app"
    private let session: AirshipRequestSession
    private let config: RuntimeConfig

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

    func fetchRemoteData(
        locale: Locale,
        randomValue: Int,
        lastModified: String?
    ) async throws -> AirshipHTTPResponse<RemoteDataResponse> {
        
        let url = remoteDataURL(locale: locale, randomValue: randomValue)
        let headers = ["Content-Type" : "application/json"]
        let request = AirshipRequest(
            url: url,
            headers: headers,
            method: "GET"
        )
        AirshipLogger.debug("Request to update remote data: \(request)")

        return try await self.session.performHTTPRequest(request) { data , response in
            let lastModified =
            response.allHeaderFields["Last-Modified"] as? String
            let metadata = self.metadata(
                url: url,
                lastModified: lastModified
            )
            let payloads = try self.parseResponse(
                data: data,
                metadata: metadata
            )
            return RemoteDataResponse(
                metadata: metadata,
                payloads: payloads,
                lastModified: lastModified
            )
        }
    }

    private func remoteDataURL(locale: Locale, randomValue: Int) -> URL? {
        let languageItem = URLQueryItem(
            name: "language",
            value: locale.languageCode
        )
        let countryItem = URLQueryItem(
            name: "country",
            value: locale.regionCode
        )
        let versionItem = URLQueryItem(
            name: "sdk_version",
            value: AirshipVersion.get()
        )
        let randomValue = URLQueryItem(
            name: "random_value",
            value: String(randomValue)
        )

        var components = URLComponents(string: config.remoteDataAPIURL ?? "")

        // api/remote-data/app/{appkey}/{platform}?sdk_version={version}&language={language}&country={country}
        components?.path = "/\(path)/\(config.appKey)/\("ios")"

        var queryItems = [versionItem]

        if languageItem.value != nil && (languageItem.value?.count ?? 0) != 0 {
            queryItems.append(languageItem)
        }

        if countryItem.value != nil && (countryItem.value?.count ?? 0) != 0 {
            queryItems.append(countryItem)
        }

        if randomValue.value != nil && (randomValue.value?.count ?? 0) != 0 {
            queryItems.append(randomValue)
        }

        components?.queryItems = queryItems as [URLQueryItem]
        return components?.url
    }

    public func metadata(
        locale: Locale,
        randomValue: Int,
        lastModified: String?
    )
        -> [AnyHashable: Any]
    {
        guard let url = remoteDataURL(locale: locale, randomValue: randomValue)
        else {
            return [:]
        }

        return self.metadata(url: url, lastModified: lastModified)
    }

    private func metadata(url: URL?, lastModified: String?) -> [AnyHashable:
        Any]
    {
        return [
            RemoteDataAPIClient.urlMetadataKey: url?.absoluteString ?? "",
            RemoteDataAPIClient.lastModifiedMetadataKey: lastModified ?? "",
        ]
    }

    private func parseResponse(data: Data?, metadata: [AnyHashable: Any]) throws
        -> [RemoteDataPayload]
    {
        guard let data = data else {
            throw AirshipErrors.parseError(
                "Refresh remote data missing response body."
            )
        }

        guard
            let jsonResponse = try JSONSerialization.jsonObject(
                with: data,
                options: .allowFragments
            ) as? [AnyHashable: Any],
            let payloads = jsonResponse["payloads"] as? [Any]
        else {
            return []
        }

        return payloads.compactMap { self.parsePayload($0, metadata: metadata) }
    }

    private func parsePayload(_ payload: Any, metadata: [AnyHashable: Any])
        -> RemoteDataPayload?
    {
        guard let payload = payload as? [AnyHashable: Any] else {
            AirshipLogger.error("Invalid payload.")
            return nil
        }

        guard let type = payload["type"] as? String, !type.isEmpty else {
            AirshipLogger.error("Invalid payload: \(payload). Missing type.")
            return nil
        }

        guard let timestampString = payload["timestamp"] as? String,
            let timestamp = AirshipUtils.parseISO8601Date(from: timestampString)
        else {
            AirshipLogger.error(
                "Invalid payload: \(payload). Missing or invalid timestamp."
            )
            return nil
        }

        guard let data = payload["data"] as? [AnyHashable: Any] else {
            AirshipLogger.error("Invalid payload: \(payload). Missing data.")
            return nil
        }

        return RemoteDataPayload(
            type: type,
            timestamp: timestamp,
            data: data,
            metadata: metadata
        )
    }
}
