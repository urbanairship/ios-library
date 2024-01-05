/* Copyright Airship and Contributors */

import CommonCrypto


public protocol AirshipRequestSession: Sendable {

    /// Performs an HTTP request
    /// - Parameters:
    ///    - request: The request
    ///    - autoCancel: If the request should be cancelled if the task is cancelled. Defaults to false.
    /// - Returns: An AirshipHTTPResponse.
    func performHTTPRequest(
        _ request: AirshipRequest,
        autoCancel: Bool
    ) async throws -> AirshipHTTPResponse<Void>

    /// Performs an HTTP request
    /// - Parameters:
    ///    - request: The request
    ///    - autoCancel: If the request should be cancelled if the task is cancelled. Defaults to false.
    /// - Returns: An AirshipHTTPResponse.
    func performHTTPRequest(
        _ request: AirshipRequest
    ) async throws -> AirshipHTTPResponse<Void>

    /// Performs an HTTP request
    /// - Parameters:
    ///    - request: The request
    ///    - autoCancel: If the request should be cancelled if the task is cancelled. Defaults to false.
    ///    - responseParser: A block that parses the response.
    /// - Returns: An AirshipHTTPResponse.
    func performHTTPRequest<T>(
        _ request: AirshipRequest,
        autoCancel: Bool,
        responseParser: ((Data?, HTTPURLResponse) throws -> T?)?
    ) async throws -> AirshipHTTPResponse<T>

    /// Performs an HTTP request
    /// - Parameters:
    ///    - request: The request
    ///    - responseParser: A block that parses the response.
    /// - Returns: An AirshipHTTPResponse.
    func performHTTPRequest<T>(
        _ request: AirshipRequest,
        responseParser: ((Data?, HTTPURLResponse) throws -> T?)?
    ) async throws -> AirshipHTTPResponse<T>
}


/// Airship request session.
/// - Note: For internal use only. :nodoc:
final class DefaultAirshipRequestSession: AirshipRequestSession, @unchecked Sendable {

    private let session: URLRequestSessionProtocol
    private let defaultHeaders: [String: String]
    private let appSecret: String
    private let appKey: String
    private let date: AirshipDateProtocol
    private let nonceFactory: () -> String

    private var authTasks: [AirshipRequestAuth: Task<ResolvedAuth, Error>] = [:]


    @MainActor
    var channelAuthTokenProvider: AuthTokenProvider?

    @MainActor
    var contactAuthTokenProvider: AuthTokenProvider?

    private static let sharedURLSession: URLRequestSessionProtocol = {
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

    init(
        appKey: String,
        appSecret: String,
        session: URLRequestSessionProtocol = DefaultAirshipRequestSession.sharedURLSession,
        date: AirshipDateProtocol = AirshipDate.shared,
        nonceFactory: @Sendable @escaping () -> String = { return UUID().uuidString }
    ) {
        self.appKey = appKey
        self.appSecret = appSecret
        self.session = session
        self.date = date
        self.nonceFactory = nonceFactory
        self.defaultHeaders = [
            "Accept-Encoding": "gzip;q=1.0, compress;q=0.5",
            "User-Agent": "(UALib \(AirshipVersion.get()); \(appKey))",
            "X-UA-App-Key": appKey,
        ]
    }


    func performHTTPRequest(
        _ request: AirshipRequest
    ) async throws -> AirshipHTTPResponse<Void> {
        return try await self.performHTTPRequest(
            request,
            autoCancel: false,
            responseParser: nil
        )
    }

    func performHTTPRequest(
        _ request: AirshipRequest,
        autoCancel: Bool
    ) async throws -> AirshipHTTPResponse<Void> {
        return try await self.performHTTPRequest(
            request,
            autoCancel: autoCancel,
            responseParser: nil
        )
    }

    func performHTTPRequest<T>(
        _ request: AirshipRequest,
        responseParser: ((Data?, HTTPURLResponse) throws -> T?)?
    ) async throws -> AirshipHTTPResponse<T> {
        return try await self.performHTTPRequest(
            request,
            autoCancel: false,
            responseParser: responseParser
        )
    }

    func performHTTPRequest<T>(
        _ request: AirshipRequest,
        autoCancel: Bool = false,
        responseParser: ((Data?, HTTPURLResponse) throws -> T?)?
    ) async throws -> AirshipHTTPResponse<T> {
        let result = try await self.doPerformHTTPRequest(
            request,
            autoCancel: autoCancel,
            responseParser: responseParser
        )

        if (result.shouldRetry) {
            return try await self.doPerformHTTPRequest(
                request,
                autoCancel: autoCancel,
                responseParser: responseParser
            ).response
        } else {
            return result.response
        }
    }

    private func doPerformHTTPRequest<T>(
        _ request: AirshipRequest,
        autoCancel: Bool = false,
        responseParser: ((Data?, HTTPURLResponse) throws -> T?)?
    ) async throws -> (shouldRetry: Bool, response: AirshipHTTPResponse<T>) {
        let cancellable = CancellableValueHolder<AirshipCancellable>() { cancellable in
            cancellable.cancel()
        }

        guard let url = request.url else {
            throw AirshipErrors.error(
                "Attempted to perform request with a missing URL."
            )
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpShouldHandleCookies = false
        urlRequest.httpMethod = request.method ?? ""

        var headers = request.headers.merging(self.defaultHeaders) { (current, _) in
            current
        }

        let resolvedAuth = try await resolveAuth(requestAuth: request.auth)
        if let authHeaders = resolvedAuth?.headers {
            headers.merge(authHeaders) { (current, _) in current }
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


        let result: AirshipHTTPResponse<T> = try await withTaskCancellationHandler(
            operation: {

                return try await withCheckedThrowingContinuation {
                    continuation in

                    cancellable.value = self.session.dataTask(request: urlRequest) {
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
                            let headers = DefaultAirshipRequestSession.parseHeaders(headers: httpResponse.allHeaderFields)
                            let result = AirshipHTTPResponse(
                                result: try responseParser?(data, httpResponse),
                                statusCode: httpResponse.statusCode,
                                headers: headers
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
                    cancellable.cancel()
                }
            }
        )

        if result.statusCode == 401, let onExpire = resolvedAuth?.onExpire {
            await onExpire()
            return (true, result)
        }

        return (false, result)

    }


    @MainActor
    private func resolveAuth(
        requestAuth: AirshipRequestAuth?
    ) async throws -> ResolvedAuth? {

        guard let requestAuth = requestAuth else {
            return nil
        }

        switch (requestAuth) {
        case .basic(let username, let password):
            let token = try DefaultAirshipRequestSession.basicAuthValue(
                username: username,
                password: password
            )
            return ResolvedAuth(
                headers: [
                    "Authorization": "Basic \(token)"
                ]
            )

        case .basicAppAuth:
            let token = try DefaultAirshipRequestSession.basicAuthValue(
                username: appKey,
                password: appSecret
            )
            return ResolvedAuth(
                headers: [
                    "Authorization": "Basic \(token)"
                ]
            )

        case .bearer(let token):
            return ResolvedAuth(
                headers: [
                    "Authorization": "Bearer \(token)"
                ]
            )

        case .channelAuthToken(let identifier):
            return try await resolveTokenAuth(
                requestAuth: requestAuth,
                identifier: identifier,
                provider: self.channelAuthTokenProvider
            )

        case .contactAuthToken(let identifier):
            return try await resolveTokenAuth(
                requestAuth: requestAuth,
                identifier: identifier,
                provider: self.contactAuthTokenProvider
            )

        case .generatedChannelToken(let channelID):
            let nonce = self.nonceFactory()
            let timestamp = AirshipUtils.ISODateFormatterUTC().string(from: self.date.now)
            let token = try AirshipUtils.generateSignedToken(
                secret: self.appSecret,
                tokenParams: [
                    self.appKey,
                    channelID,
                    nonce,
                    timestamp
                ]
            )

            return ResolvedAuth(
                headers: [
                    "Authorization": "Bearer \(token)",
                    "X-UA-Appkey": self.appKey,
                    "X-UA-Channel-ID": channelID,
                    "X-UA-Nonce": nonce,
                    "X-UA-Timestamp": timestamp
                ]
            )

        case .generatedAppToken:
            let nonce = self.nonceFactory()
            let timestamp = AirshipUtils.ISODateFormatterUTC().string(from: self.date.now)
            let token = try AirshipUtils.generateSignedToken(
                secret: self.appSecret,
                tokenParams: [
                    self.appKey,
                    nonce,
                    timestamp
                ]
            )

            return ResolvedAuth(
                headers: [
                    "Authorization": "Bearer \(token)",
                    "X-UA-Appkey": self.appKey,
                    "X-UA-Nonce": nonce,
                    "X-UA-Timestamp": timestamp
                ]
            )
        }
    }

    private class func basicAuthValue(username: String, password: String) throws -> String {
        let credentials = "\(username):\(password)"


        guard let encodedCredentials = credentials.data(using: .utf8) else {
            throw AirshipErrors.error("Invalid basic auth for user \(username)")
        }


        return encodedCredentials.base64EncodedString(options: [])
    }

    @MainActor
    private func resolveTokenAuth(
        requestAuth: AirshipRequestAuth,
        identifier: String,
        provider: AuthTokenProvider?
    ) async throws -> ResolvedAuth {
        guard let provider = provider else {
            throw AirshipErrors.error("Missing auth provider for auth \(requestAuth)")
        }

        if let existingTask = self.authTasks[requestAuth] {
            return try await existingTask.value
        }

        let task = Task { @MainActor in
            defer {
                self.authTasks[requestAuth] = nil
            }

            let token = try await provider.resolveAuth(
                identifier: identifier
            )
            
            return ResolvedAuth(
                headers: [
                    "Authorization": "Bearer \(token)",
                    "X-UA-Appkey": self.appKey
                ]
            ) {
                await provider.authTokenExpired(token: token)
            }
        }

        self.authTasks[requestAuth] = task
        return try await task.value
    }

    private class func parseHeaders(headers: [AnyHashable: Any]) -> [String: String] {
        if let headers = headers as? [String : String] {
            return headers
        }

        return Dictionary(
            uniqueKeysWithValues: headers.compactMap { (key, value) in
                if let key = key as? String, let value = value as? String {
                    return (key, value)
                }
                return nil
            }
        )
    }
}

protocol AuthTokenProvider: Sendable {
    func resolveAuth(identifier: String) async throws -> String
    func authTokenExpired(token: String) async
}

/// - Note: For internal use only. :nodoc:
public enum AirshipRequestAuth: Sendable, Equatable, Hashable {
    case basic(username: String, password: String)
    case bearer(token: String)
    case basicAppAuth
    case channelAuthToken(identifier: String)
    case contactAuthToken(identifier: String)
    case generatedChannelToken(identifier: String)
    case generatedAppToken
}


fileprivate struct ResolvedAuth: Sendable {
    let headers: [String: String]
    let onExpire: (@Sendable () async -> Void)?

    init(headers: [String: String], onExpire: (@Sendable () async -> Void)? = nil) {
        self.headers = headers
        self.onExpire = onExpire
    }
}

extension Data {
    fileprivate func gzip() -> Data? {
        return UACompression.gzipData(self)
    }
}

protocol URLRequestSessionProtocol: Sendable {
    @discardableResult
    func dataTask(
        request: URLRequest,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    )
        -> AirshipCancellable
}

extension URLSession: URLRequestSessionProtocol {
    @discardableResult
    func dataTask(
        request: URLRequest,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    )
        -> AirshipCancellable
    {
        let task = self.dataTask(
            with: request,
            completionHandler: completionHandler
        )
        task.resume()

        return CancellableValueHolder(value: task) { task in
            task.cancel()
        }
    }
}



