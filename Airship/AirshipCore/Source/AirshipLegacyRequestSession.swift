/* Copyright Airship and Contributors */

// NOTE: For internal use only. :nodoc:
@objc(UARequestSession)
open class AirshipLegacyRequestSession: NSObject {

    private let session: AirshipRequestSession

    @objc
    public init(config: RuntimeConfig) {
        self.session = config.requestSession
    }

    @objc
    open func performHTTPRequest(
        _ request: AirshipLegacyRequest,
        completionHandler: @escaping (Data?, HTTPURLResponse?, Error?) -> Void
    ) {
        let airshipRequest = AirshipRequest(
            url: request.url,
            headers: request.headers ?? [:],
            method: request.method,
            auth: request.auth,
            body: request.body
        )

        Task {
            do {
                var response: AirshipHTTPResponse<(Data?, HTTPURLResponse)>!
                response = try await self.session.performHTTPRequest(
                    airshipRequest
                ) {
                    data,
                    response in
                    return (data, response)
                }
                completionHandler(response.result?.0, response.result?.1, nil)
            } catch {
                completionHandler(nil, nil, error)
            }
        }
    }
}

// NOTE: For internal use only. :nodoc:
@objc(UAHTTPResponse)
public class AirshipLegacyHTTPResponse: NSObject {
    @objc
    public let status: Int

    public override var debugDescription: String {
        return "HTTPResponse(status=\(status))"
    }

    @objc
    public override var description: String {
        return self.debugDescription
    }

    @objc
    public init(status: Int) {
        self.status = status
    }

    @objc
    public var isSuccess: Bool {
        return status >= 200 && status <= 299
    }

    @objc
    public var isClientError: Bool {
        return status >= 400 && status <= 499
    }

    @objc
    public var isServerError: Bool {
        return status >= 500 && status <= 599
    }
}

// NOTE: For internal use only. :nodoc:
@objc(UARequest)
public class AirshipLegacyRequest: NSObject {
    @objc
    public let method: String
    @objc
    public let url: URL
    @objc
    public let headers: [String: String]?
    @objc
    public let body: Data?

    fileprivate let auth: AirshipRequestAuth?

    private init(method: String, url: URL, headers: [String : String]?, body: Data?, auth: AirshipRequestAuth?) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
        self.auth = auth
    }

    @objc
    public static func makeChannelAuthRequest(
        channelID: String,
        method: String,
        url: URL,
        headers: [String : String]?,
        body: Data?
    ) -> AirshipLegacyRequest {
        return AirshipLegacyRequest(
            method: method,
            url: url,
            headers: headers,
            body: body,
            auth: .channelAuthToken(identifier: channelID)
        )
    }
}
