/* Copyright Airship and Contributors */

public import Foundation

@testable
public import AirshipCore

public final class TestAirshipRequestSession: AirshipRequestSession, @unchecked Sendable {

    public var previousRequest: AirshipRequest?
    public var lastRequest: AirshipRequest?
    public var response: HTTPURLResponse?
    public var error: (any Error)?
    public var data: Data?

    
    public func performHTTPRequest(
        _ request: AirshipRequest
    ) async throws -> AirshipHTTPResponse<Void> {
        return try await self.performHTTPRequest(
            request,
            autoCancel: false,
            responseParser: nil
        )
    }

    public func performHTTPRequest(
        _ request: AirshipRequest,
        autoCancel: Bool
    ) async throws -> AirshipHTTPResponse<Void> {
        return try await self.performHTTPRequest(
            request,
            autoCancel: autoCancel,
            responseParser: nil
        )
    }

    public func performHTTPRequest<T>(
        _ request: AirshipRequest,
        responseParser: (@Sendable (Data?, HTTPURLResponse) throws -> T?)?
    ) async throws -> AirshipHTTPResponse<T> {
        return try await self.performHTTPRequest(
            request,
            autoCancel: false,
            responseParser: responseParser
        )
    }

    @MainActor
    public func performHTTPRequest<T>(
        _ request: AirshipRequest,
        autoCancel: Bool,
        responseParser: (@Sendable (Data?, HTTPURLResponse) throws -> T?)?
    ) async throws -> AirshipHTTPResponse<T> {
        self.previousRequest = self.lastRequest
        self.lastRequest = request

        if let error = self.error {
            throw error
        }

        guard let response else {
            throw AirshipErrors.error("No response")
        }

        let result = AirshipHTTPResponse(
            result: try responseParser?(data, response),
            statusCode: response.statusCode,
            headers: response.allHeaderFields as? [String: String] ?? [:]
        )
        return result
    }

}
