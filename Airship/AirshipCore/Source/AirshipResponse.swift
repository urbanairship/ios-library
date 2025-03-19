/* Copyright Airship and Contributors */

import Foundation

/// AirshipHTTPResponse when using AirshipRequestSession
/// - Note: For internal use only. :nodoc:
public struct AirshipHTTPResponse<T: Sendable>: Sendable {
    public let result: T?
    public let statusCode: Int
    public let headers: [String: String]
}

extension AirshipHTTPResponse {
    public var isSuccess: Bool {
        return self.statusCode >= 200 && self.statusCode <= 299
    }

    public var isClientError: Bool {
        return self.statusCode >= 400 && self.statusCode <= 499
    }

    public var isServerError: Bool {
        return self.statusCode >= 500 && self.statusCode <= 599
    }
}


extension AirshipHTTPResponse: Equatable where T: Equatable {}

extension AirshipHTTPResponse {
    func map<R>(onMap: (AirshipHTTPResponse<T>) throws -> R?) throws -> AirshipHTTPResponse<R> {
        return AirshipHTTPResponse<R>(
            result:  try onMap(self),
            statusCode: self.statusCode,
            headers: self.headers
        )
    }
}
