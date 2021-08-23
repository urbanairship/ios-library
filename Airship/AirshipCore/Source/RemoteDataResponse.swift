/* Copyright Airship and Contributors */

// NOTE: For internal use only. :nodoc:
@objc(UARemoteDataResponse)
public class RemoteDataResponse : UAHTTPResponse {

    @objc
    public let payloads: [RemoteDataPayload]?

    @objc
    public let lastModified: String?

    @objc
    public let metadata: [AnyHashable : Any]?

    @objc
    public init(
        status: Int,
        metadata: [AnyHashable : Any]?,
        payloads: [RemoteDataPayload]?,
        lastModified: String?
    ) {
        self.metadata = metadata
        self.payloads = payloads
        self.lastModified = lastModified
        super.init(status: status)
    }
}
