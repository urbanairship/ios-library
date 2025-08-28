/* Copyright Airship and Contributors */




protocol RemoteDataProviderDelegate: Sendable {
    var source: RemoteDataSource { get }
    var storeName: String { get }

    func isRemoteDataInfoUpToDate(
        _  remoteDataInfo: RemoteDataInfo,
        locale: Locale,
        randomValue: Int
    ) async -> Bool

    func fetchRemoteData(
        locale: Locale,
        randomValue: Int,
        lastRemoteDataInfo: RemoteDataInfo?
    ) async throws -> AirshipHTTPResponse<RemoteDataResult>
}
