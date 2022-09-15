/* Copyright Airship and Contributors */

@objc(UARequestSession)
open class RequestSession: NSObject {

    private let session: AirshipRequestSession

    @objc
    public init(config: RuntimeConfig) {
        self.session = AirshipRequestSession(appKey: config.appKey)
    }

    @objc
    @discardableResult
    open func performHTTPRequest(
        _ request: Request,
        completionHandler: @escaping (Data?, HTTPURLResponse?, Error?) -> Void)
    -> Disposable {

        var auth: AirshipRequest.Auth? = nil
        if let username = request.username, let password = request.password {
            auth = .basic(username, password)
        }

        let airshipRequest = AirshipRequest(
            url: request.url,
            headers: request.headers,
            method: request.method,
            auth: auth,
            body: request.body,
            compressBody: request.compressBody
        )

        let task = Task {
            do {
                var response: AirshipHTTPResponse<(Data?, HTTPURLResponse)>!
                response = try await self.session.performHTTPRequest(airshipRequest) { data, response in
                    return (data, response)
                }
                completionHandler(response.result?.0, response.result?.1, nil)
            } catch {
                completionHandler(nil, nil, error)
            }
        }

        return Disposable {
            task.cancel()
        }
    }
}
