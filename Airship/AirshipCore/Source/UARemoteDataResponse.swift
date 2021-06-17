/* Copyright Airship and Contributors */

/**
 * @note For internal use only. :nodoc:
 */
@objc
public class UARemoteDataResponse : UAHTTPResponse {

    @objc
    public var payloads: [AnyHashable]?

    @objc
    public var lastModified: String?

    @objc
    public var requestURL: URL?

    @objc
    public init(
        status: Int,
        requestURL: URL?,
        payloads: [AnyHashable]?,
        lastModified: String?
    ) {
        super.init(status: status)
        self.requestURL = requestURL
        self.payloads = payloads
        self.lastModified = lastModified
    }
}
