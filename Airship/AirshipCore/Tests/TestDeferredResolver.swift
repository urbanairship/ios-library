/* Copyright Airship and Contributors */

@testable
import AirshipCore

import Foundation

final actor TestDeferredResolver: AirshipDeferredResolverProtocol {
    var dataCallback: ((DeferredRequest) async -> AirshipDeferredResult<Data>)?

    func onData(_ onData: @escaping (DeferredRequest) async -> AirshipDeferredResult<Data>) {
        self.dataCallback = onData
    }

    func resolve<T>(
        request: DeferredRequest,
        resultParser: @escaping @Sendable (Data) async throws -> T
    ) async -> AirshipDeferredResult<T> where T : Sendable {
        switch(await dataCallback?(request) ?? .timedOut) {
        case .success(let data):
            do {
                let value = try await resultParser(data)
                return .success(value)
            } catch {
                return .retriableError(statusCode: 200)
            }
        case .timedOut: return .timedOut
        case .outOfDate: return .outOfDate
        case .notFound: return .notFound
        case .retriableError(retryAfter: let retryAfter, statusCode: let statusCode): return .retriableError(retryAfter: retryAfter, statusCode:statusCode)
        }
    }
}
