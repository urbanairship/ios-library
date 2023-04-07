import Foundation

@testable
import AirshipCore

class TestRemoteDataAPIClient: RemoteDataAPIClientProtocol {
    
    @objc
    public var metdataCallback: ((Locale, String?) -> [AnyHashable: String])?
    
    public var fetchData:
    (
        (Locale, String?) async throws -> AirshipHTTPResponse<RemoteDataResponse>
    )?
    
    public func fetchRemoteData(
        locale: Locale,
        randomValue: Int,
        lastModified: String?
    ) async throws -> AirshipHTTPResponse<RemoteDataResponse> {
        guard let block = fetchData else {
            throw AirshipErrors.error("Request block not set")
        }
        
        return try await block(locale, lastModified)
    }
    
    public func metadata(
        locale: Locale,
        randomValue: Int,
        lastModified: String?
    ) -> [AnyHashable: Any]
    {
        return self.metdataCallback?(locale, lastModified) ?? [:]
    }
}
