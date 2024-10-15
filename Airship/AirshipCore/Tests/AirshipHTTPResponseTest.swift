/* Copyright Airship and Contributors */

import XCTest

@testable
public import AirshipCore

public extension AirshipHTTPResponse {
    
    static func make(result: T?, statusCode: Int, headers: [String: String]) -> AirshipHTTPResponse<T> {
        return .init(result: result, statusCode: statusCode, headers: headers)
    }
}
