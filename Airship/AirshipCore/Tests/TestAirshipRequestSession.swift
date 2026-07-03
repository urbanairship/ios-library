/* Copyright Airship and Contributors */

public import Foundation
@_spi(AirshipInternal) import AirshipBasement

@testable
public import AirshipCore

public final class TestAirshipRequestSession: AirshipRequestSession, @unchecked Sendable {

    public var previousRequest: AirshipRequest?
    public var lastRequest: AirshipRequest?
    public var response: HTTPURLResponse?
    public var error: (any Error)?
    public var data: Data?

    /// When non-empty, each `performHTTPRequest` consumes the next `(HTTPURLResponse, body)` and ignores
    /// `response`, `data`, and `error` until the script is exhausted; then behavior falls back to those properties.
    public var responseScript: [(response: HTTPURLResponse, data: Data?)] = []

    private let lock = NSLock()
    private var scriptIndex = 0

    /// Increments on every `performHTTPRequest` invocation.
    public private(set) var requestInvocationCount = 0

    
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

        let scriptEntry: (HTTPURLResponse, Data?)? = lock.withLock {
            self.requestInvocationCount += 1
            if scriptIndex < responseScript.count {
                let step = responseScript[scriptIndex]
                scriptIndex += 1
                return (step.response, step.data)
            } else {
                return nil
            }
        }

        let response: HTTPURLResponse
        let body: Data?

        if let entry = scriptEntry {
            response = entry.0
            body = entry.1
        } else {
            if let error = self.error {
                throw error
            }

            guard let fallback = self.response else {
                throw AirshipErrors.error("No response")
            }

            response = fallback
            body = self.data
        }

        let result = AirshipHTTPResponse(
            result: try responseParser?(body, response),
            statusCode: response.statusCode,
            headers: response.allHeaderFields as? [String: String] ?? [:]
        )
        return result
    }

}
