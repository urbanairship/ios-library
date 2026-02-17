/* Copyright Airship and Contributors */

import Foundation

/// Content encoding type for request body compression.
/// - Note: For internal use only. :nodoc:
public enum ContentEncoding: String, Sendable, Equatable {
    case deflate
}

/// AirshipRequest
/// - Note: For internal use only. :nodoc:
public struct AirshipRequest: Sendable {
    let url: URL?
    let headers: [String: String]
    let method: String?
    let auth: AirshipRequestAuth?
    let body: Data?
    let contentEncoding: ContentEncoding?

    public init(
        url: URL?,
        headers: [String: String] = [:],
        method: String? = nil,
        auth: AirshipRequestAuth? = nil,
        body: Data? = nil,
        contentEncoding: ContentEncoding? = nil
    ) {
        self.url = url
        self.headers = headers
        self.method = method
        self.auth = auth
        self.body = body
        self.contentEncoding = contentEncoding
    }
}
