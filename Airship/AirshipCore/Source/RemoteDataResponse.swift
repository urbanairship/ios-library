/* Copyright Airship and Contributors */

// NOTE: For internal use only. :nodoc:
@objc(UARemoteDataResponse)
public class RemoteDataResponse : HTTPResponse {

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
