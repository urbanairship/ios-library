/* Copyright Airship and Contributors */



struct ContactRemoteDataProviderDelegate: RemoteDataProviderDelegate {
    let source: RemoteDataSource = .contact
    let storeName: String

    private let config: RuntimeConfig
    private let apiClient: any RemoteDataAPIClientProtocol
    private let contact: any InternalAirshipContactProtocol

    init(config: RuntimeConfig, apiClient: any RemoteDataAPIClientProtocol, contact: any InternalAirshipContactProtocol) {
        self.storeName = "RemoteData-Contact-\(config.appCredentials.appKey).sqlite"
        self.config = config
        self.apiClient = apiClient
        self.contact = contact
    }

    private func makeURL(contactID: String, locale: Locale, randomValue: Int) throws -> URL {
        return try RemoteDataURLFactory.makeURL(
            config: config,
            path: "/api/remote-data-contact/ios/\(contactID)",
            locale: locale,
            randomValue: randomValue
        )
    }

    func isRemoteDataInfoUpToDate(
        _ remoteDataInfo: RemoteDataInfo,
        locale: Locale,
        randomValue: Int
    ) async -> Bool {
        let contactInfo = await contact.contactIDInfo
        guard let contactInfo = contactInfo, contactInfo.isStable else { return false }

        let url = try? self.makeURL(contactID: contactInfo.contactID, locale: locale, randomValue: randomValue)
        return remoteDataInfo.url == url && remoteDataInfo.contactID == contactInfo.contactID
    }

    func fetchRemoteData(
        locale: Locale,
        randomValue: Int,
        lastRemoteDataInfo: RemoteDataInfo?
    ) async throws -> AirshipHTTPResponse<RemoteDataResult> {
        let stableContactID = await contact.getStableContactID()
        let url = try self.makeURL(contactID: stableContactID, locale: locale, randomValue: randomValue)

        var lastModified: String? = nil
        if (lastRemoteDataInfo?.url == url) {
            lastModified = lastRemoteDataInfo?.lastModifiedTime
        }

        return try await self.apiClient.fetchRemoteData(
            url: url,
            auth: .contactAuthToken(identifier: stableContactID),
            lastModified: lastModified
        ) { newLastModified in
            return RemoteDataInfo(
                url: url,
                lastModifiedTime: newLastModified,
                source: .contact,
                contactID: stableContactID
            )
        }
    }
}
