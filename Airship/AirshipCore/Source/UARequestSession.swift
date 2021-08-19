/* Copyright Airship and Contributors */

@objc
open class UARequestSession : NSObject {
    private var session: URLSession
    private var headers: [String : String] = [:]

    public static var sharedURLSession: URLSession = UARequestSession.createSession()

    @objc
    public init(config: RuntimeConfig, session: URLSession) {
        self.session = session
        super.init()
        self.setValue("gzip;q=1.0, compress;q=0.5", header: "Accept-Encoding")
        self.setValue(UARequestSession.userAgent(withAppKey: config.appKey), header: "User-Agent")
        self.setValue(config.appKey, header: "X-UA-App-Key")
    }

    @objc
    public convenience init(config: RuntimeConfig) {
        self.init(config: config, session: UARequestSession.sharedURLSession)
    }


    private static func createSession() -> URLSession {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.urlCache = nil
        sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        sessionConfig.tlsMinimumSupportedProtocol = .tlsProtocol12
        return URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)
    }

    @objc
    public func setValue(_ value: String?, header: String) {
        headers[header] = value
    }

    @objc
    @discardableResult
    open func performHTTPRequest(_ request: UARequest, completionHandler: @escaping (Data?, HTTPURLResponse?, Error?) -> Void) -> UADisposable {
        guard request.url != nil && request.url?.host != nil else {
            session.delegateQueue.addOperation({
                let error = AirshipErrors.error("Attempted to perform request with a missing URL.")
                completionHandler(nil, nil ,error)
            })

            return UADisposable()
        }


        var urlRequest = URLRequest(url: request.url!)
        urlRequest.httpShouldHandleCookies = false
        urlRequest.httpMethod = request.method ?? ""
        urlRequest.httpBody = request.body
        for (k, v) in request.headers { urlRequest.setValue(v, forHTTPHeaderField: k) }
        for (k, v) in self.headers { urlRequest.setValue(v, forHTTPHeaderField: k) }

        let task = self.session.dataTask(with: urlRequest) { (data, response, error) in
            guard (error == nil && response != nil) else {
                completionHandler(nil, nil, error)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completionHandler(data, nil,  AirshipErrors.error("Unable to cast to HTTPURLResponse: \(response!)"))
                return
            }

            completionHandler(data, httpResponse, nil)
        }


        task.resume()

        return UADisposable({
            task.cancel()
        })
    }

    private class func userAgent(withAppKey appKey: String) -> String? {
        return "(UALib \(UAirshipVersion.get()); \(appKey))"
    }
}
