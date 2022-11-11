/* Copyright Airship and Contributors */

/// Airship request session.
/// - Note: For internal use only. :nodoc:
public class AirshipRequestSession {

    private let session: URLRequestSessionProtocol
    private let headers: [String: String]

    private static var sharedURLSession: URLRequestSessionProtocol = {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.urlCache = nil
        sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        sessionConfig.tlsMinimumSupportedProtocolVersion = .TLSv12
        return URLSession(
            configuration: sessionConfig,
            delegate: nil,
            delegateQueue: nil
        )
    }()

    public init(appKey: String) {
        self.session = AirshipRequestSession.sharedURLSession
        self.headers = AirshipRequestSession.makeDefaultHeaders(appKey: appKey)
    }

    init(
        appKey: String,
        session: URLRequestSessionProtocol
    ) {
        self.session = session
        self.headers = AirshipRequestSession.makeDefaultHeaders(appKey: appKey)
    }

    private static func makeDefaultHeaders(appKey: String) -> [String: String] {
        return [
            "Accept-Encoding": "gzip;q=1.0, compress;q=0.5",
            "User-Agent": "(UALib \(AirshipVersion.get()); \(appKey))",
            "X-UA-App-Key": appKey,
        ]
    }

    /// Performs an HTTP request
    /// - Parameters:
    ///    - request: The request
    ///    - autoCancel: If the request should be cancelled if the task is cancelled. Defaults to false.
    /// - Returns: An AirshipHTTPResponse.
    public func performHTTPRequest(
        _ request: AirshipRequest,
        autoCancel: Bool = false
    ) async throws -> AirshipHTTPResponse<Void> {
        return try await self.performHTTPRequest(request, responseParser: nil)
    }

    /// Performs an HTTP request
    /// - Parameters:
    ///    - request: The request
    ///    - autoCancel: If the request should be cancelled if the task is cancelled. Defaults to false.
    ///    - responseParser: A block that parses the response.
    /// - Returns: An AirshipHTTPResponse.
    public func performHTTPRequest<T>(
        _ request: AirshipRequest,
        autoCancel: Bool = false,
        responseParser: ((Data?, HTTPURLResponse) throws -> T?)?
    ) async throws -> AirshipHTTPResponse<T> {

        guard let url = request.url else {
            throw AirshipErrors.error(
                "Attempted to perform request with a missing URL."
            )
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpShouldHandleCookies = false
        urlRequest.httpMethod = request.method ?? ""

        var headers = request.headers.merging(self.headers) { (current, _) in
            current
        }

        if let auth = request.auth {
            headers["Authorization"] = auth.authorizaitionValue
        }

        if request.compressBody == true {
            if let gzipped = request.body?.gzip() {
                urlRequest.httpBody = gzipped
                headers["Content-Encoding"] = "gzip"
            } else {
                urlRequest.httpBody = request.body
            }
        } else {
            urlRequest.httpBody = request.body
        }

        for (k, v) in headers { urlRequest.setValue(v, forHTTPHeaderField: k) }

        var disposable: Disposable?
        let onCancel = {
            disposable?.dispose()
        }

        return try await withTaskCancellationHandler(
            operation: {
                return try await withCheckedThrowingContinuation {
                    continuation in
                    disposable = self.session.dataTask(request: urlRequest) {
                        (data, response, error) in
                        if let error = error {
                            continuation.resume(throwing: error)
                            return
                        }

                        guard let response = response else {
                            let error = AirshipErrors.error("Missing response")
                            continuation.resume(throwing: error)
                            return
                        }

                        guard let httpResponse = response as? HTTPURLResponse
                        else {
                            let error = AirshipErrors.error(
                                "Unable to cast to HTTPURLResponse: \(response)"
                            )
                            continuation.resume(throwing: error)
                            return
                        }

                        do {
                            let result = AirshipHTTPResponse(
                                result: try responseParser?(data, httpResponse),
                                statusCode: httpResponse.statusCode,
                                headers: httpResponse.allHeaderFields
                            )
                            continuation.resume(with: .success(result))
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            },
            onCancel: {
                if autoCancel {
                    onCancel()
                }
            }
        )
    }
}

extension Data {
    fileprivate func gzip() -> Data? {
        return UACompression.gzipData(self)
    }
}

extension AirshipRequest.Auth {
    fileprivate var authorizaitionValue: String {
        switch self {
        case .basic(let username, let password):
            let credentials = "\(username):\(password)"
            let encodedCredentials = credentials.data(using: .utf8)
            return
                "Basic \(encodedCredentials?.base64EncodedString(options: []) ?? "")"
        }
    }
}

protocol URLRequestSessionProtocol {
    @discardableResult
    func dataTask(
        request: URLRequest,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    )
        -> Disposable
}

extension URLSession: URLRequestSessionProtocol {
    @discardableResult
    func dataTask(
        request: URLRequest,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    )
        -> Disposable
    {
        let task = self.dataTask(
            with: request,
            completionHandler: completionHandler
        )
        task.resume()

        return Disposable {
            task.cancel()
        }
    }
}
