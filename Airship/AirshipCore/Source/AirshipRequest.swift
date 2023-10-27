/* Copyright Airship and Contributors */

import Foundation

/// AirshipRequest
/// - Note: For internal use only. :nodoc:
public struct AirshipRequest: Sendable {
    let url: URL?
    let headers: [String: String]
    let method: String?
    let auth: AirshipRequestAuth?
    let body: Data?
    let compressBody: Bool

    public init(
        url: URL?,
        headers: [String: String] = [:],
        method: String? = nil,
        auth: AirshipRequestAuth? = nil,
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
}
