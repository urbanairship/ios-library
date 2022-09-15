/* Copyright Airship and Contributors */

import Foundation

/// AirshipRequest
/// - Note: For internal use only. :nodoc:
public struct AirshipRequest {
    let url: URL?
    let headers: [String: String]
    let method: String?
    let auth: Auth?
    let body: Data?
    let compressBody: Bool

    public init(
        url: URL?,
        headers: [String: String] = [:],
        method: String? = nil,
        auth: Auth? = nil,
        body: Data? = nil,
        compressBody: Bool = false
    ) {
        self.url = url
        self.headers = headers
        self.method = method
        self.auth = auth
        self.body = body
        self.compressBody = compressBody
    }

    public enum Auth {
        case basic(String, String)
    }
}
