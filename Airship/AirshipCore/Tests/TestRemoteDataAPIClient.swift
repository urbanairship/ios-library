

@testable
import AirshipCore

final class TestRemoteDataAPIClient: RemoteDataAPIClientProtocol, @unchecked Sendable {

    public var fetchData: (
        (URL, AirshipRequestAuth, String?, RemoteDataInfo) async throws -> AirshipHTTPResponse<RemoteDataResult>
    )?

    public var lastModified: String? = nil

    func fetchRemoteData(
        url: URL,
        auth: AirshipRequestAuth,
        lastModified: String?,
        remoteDataInfoBlock: @escaping @Sendable (String?) throws -> AirshipCore.RemoteDataInfo
    ) async throws -> AirshipCore.AirshipHTTPResponse<AirshipCore.RemoteDataResult> {
        try await fetchData!(url, auth, lastModified, try remoteDataInfoBlock(self.lastModified))
    }
}
