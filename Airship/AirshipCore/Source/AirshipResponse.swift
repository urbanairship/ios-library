/* Copyright Airship and Contributors */

import Foundation

/// AirshipHTTPResponse when using AirshipRequestSession
/// - Note: For internal use only. :nodoc:
public struct AirshipHTTPResponse<T> {
    public let result: T?
    public let statusCode: Int
    public let headers: [AnyHashable: Any]
}

public extension AirshipHTTPResponse {
    var isSuccess: Bool {
        return self.statusCode >= 200 && self.statusCode <= 299
    }

    var isClientError: Bool {
        return self.statusCode >= 400 && self.statusCode <= 499
    }

    var isServerError: Bool {
        return self.statusCode >= 500 && self.statusCode <= 599
    }
}
