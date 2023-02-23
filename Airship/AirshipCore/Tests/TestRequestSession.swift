/* Copyright Airship and Contributors */

import Foundation
@testable import AirshipCore

public class TestRequestSession: AirshipRequestSession {

    public var previousRequest: AirshipRequest?

    public var lastRequest: AirshipRequest?

    @objc
    public var response: HTTPURLResponse?

    @objc
    public var error: Error?

    @objc
    public var data: Data?

    @objc
    public init() {
        let config = RuntimeConfig(
            config: Config(),
            dataStore: PreferenceDataStore(appKey: UUID().uuidString)
        )
        super.init(appKey:config.appKey)
    }

    public override func performHTTPRequest<T>(
        _ request: AirshipRequest,
        autoCancel: Bool = false,
        responseParser: ((Data?, HTTPURLResponse) throws -> T?)?
    ) async throws -> AirshipHTTPResponse<T> {
        self.previousRequest = self.lastRequest
        self.lastRequest = request
        return AirshipHTTPResponse(
            result: try responseParser?(data, response!),
            statusCode: response!.statusCode,
            headers: response!.allHeaderFields
        )
    }
}
