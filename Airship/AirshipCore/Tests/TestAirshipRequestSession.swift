/* Copyright Airship and Contributors */

import Foundation

@testable import AirshipCore

public class TestAirshipRequestSession: AirshipRequestSession {

    public var previousRequest: AirshipRequest?

    public var lastRequest: AirshipRequest?

    public var response: HTTPURLResponse?

    public var error: Error?

    public var data: Data?

    public init() {
        super.init(appKey: UUID().uuidString)
    }

    public override func performHTTPRequest<T>(
        _ request: AirshipRequest,
        autoCancel: Bool,
        responseParser: ((Data?, HTTPURLResponse) throws -> T?)?
    ) async throws -> AirshipHTTPResponse<T> {
        self.previousRequest = self.lastRequest
        self.lastRequest = request

        if let error = self.error {
            throw error
        }
        
        let result = AirshipHTTPResponse(
            result: try responseParser?(data, response!),
            statusCode: response!.statusCode,
            headers: response!.allHeaderFields
        )
        return result
    }

}
