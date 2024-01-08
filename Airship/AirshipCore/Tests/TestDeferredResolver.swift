/* Copyright Airship and Contributors */

@testable
import AirshipCore

import Foundation

final class TestDeferredResolver: AirshipDeferredResolverProtocol, @unchecked Sendable {
    var onData: ((DeferredRequest) async -> AirshipDeferredResult<Data>)?

    func resolve<T>(
        request: DeferredRequest,
        resultParser: @escaping @Sendable (Data) async throws -> T
    ) async -> AirshipDeferredResult<T> where T : Sendable {
        switch(await onData?(request) ?? .timedOut) {
        case .success(let data):
            do {
                let value = try await resultParser(data)
                return .success(value)
            } catch {
                return .retriableError()
            }
        case .timedOut: return .timedOut
        case .outOfDate: return .outOfDate
        case .notFound: return .notFound
        case .retriableError(retryAfter: let retryAfter): return .retriableError(retryAfter: retryAfter)
        }
    }
}
