/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

final class DefaultAirshipRequestSessionTest: AirshipBaseTest {

    private let testURLSession = TestURLRequestSession()
    private var airshipSession: DefaultAirshipRequestSession!
    private var nonce: String = UUID().uuidString

    private var date: UATestDate = UATestDate(offset: 0, dateOverride: Date())

    override func setUpWithError() throws {
        self.airshipSession = DefaultAirshipRequestSession(
            appKey: "testAppKey",
            appSecret: "testAppSecret",
            session: self.testURLSession,
            date: date
        ) {
            return self.nonce
        }
    }

    func testDefaultHeaders() async throws {
        let request = AirshipRequest(url: URL(string: "http://neat.com"))

        let _ = try? await self.airshipSession.performHTTPRequest(request)

        let headers = testURLSession.requests.last?.allHTTPHeaderFields
        let expected = [
            "Accept-Encoding": "gzip;q=1.0, compress;q=0.5",
            "User-Agent": "(UALib \(AirshipVersion.version); testAppKey)",
            "X-UA-App-Key": "testAppKey",
        ]

        XCTAssertEqual(expected, headers)
    }

    func testCombinedHeaders() async throws {
        let request = AirshipRequest(
            url: URL(string: "http://neat.com"),
            headers: [
                "foo": "bar",
                "User-Agent": "Something else",
            ]
        )

        let _ = try? await self.airshipSession.performHTTPRequest(request)

        let headers = testURLSession.requests.last?.allHTTPHeaderFields
        let expected = [
            "foo": "bar",
            "Accept-Encoding": "gzip;q=1.0, compress;q=0.5",
            "User-Agent": "Something else",
            "X-UA-App-Key": "testAppKey"
        ]

        XCTAssertEqual(expected, headers)
    }

    func testBasicAuth() async throws {
        let request = AirshipRequest(
            url: URL(string: "http://neat.com"),
            auth: .basic(username: "name", password: "password")
        )

        let _ = try? await self.airshipSession.performHTTPRequest(request)

        let auth = testURLSession.requests.last?.allHTTPHeaderFields?[
            "Authorization"
        ]
        XCTAssertEqual("Basic bmFtZTpwYXNzd29yZA==", auth)
    }

    func testAppAuth() async throws {
        let request = AirshipRequest(
            url: URL(string: "http://neat.com"),
            auth: .basicAppAuth
        )

        let _ = try? await self.airshipSession.performHTTPRequest(request)

        let auth = testURLSession.requests.last?.allHTTPHeaderFields?[
            "Authorization"
        ]
        XCTAssertEqual("Basic dGVzdEFwcEtleTp0ZXN0QXBwU2VjcmV0", auth)
    }

    @MainActor
    func testChannelAuthToken() async throws {
        let authProvider = TestAuthTokenProvider() { identifier in
            XCTAssertEqual("some identifier", identifier)
            return "some auth token"
        }
        airshipSession.channelAuthTokenProvider = authProvider

        let request = AirshipRequest(
            url: URL(string: "http://neat.com"),
            auth: .channelAuthToken(identifier: "some identifier")
        )

        let _ = try? await self.airshipSession.performHTTPRequest(request)

        let authHeaders = [
            "Authorization": "Bearer some auth token",
            "X-UA-Appkey": "testAppKey",
            "X-UA-Auth-Type": "SDK-JWT"
        ]

        let headers = testURLSession.requests.last?.allHTTPHeaderFields?.filter({ (key: String, value: String) in
            authHeaders[key] != nil
        })

        XCTAssertEqual(authHeaders, headers)
    }

    @MainActor
    func testContactAuthToken() async throws {
        let authProvider = TestAuthTokenProvider() { identifier in
            XCTAssertEqual("some contact", identifier)
            return "some auth token"
        }
        airshipSession.contactAuthTokenProvider = authProvider

        let request = AirshipRequest(
            url: URL(string: "http://neat.com"),
            auth: .contactAuthToken(identifier: "some contact")
        )

        let _ = try? await self.airshipSession.performHTTPRequest(request)

        let authHeaders = [
            "Authorization": "Bearer some auth token",
            "X-UA-Appkey": "testAppKey",
            "X-UA-Auth-Type": "SDK-JWT"
        ]

        let headers = testURLSession.requests.last?.allHTTPHeaderFields?.filter({ (key: String, value: String) in
            authHeaders[key] != nil
        })

        XCTAssertEqual(authHeaders, headers)
    }

    func testGeneratedAppToken() async throws {
        let request = AirshipRequest(
            url: URL(string: "http://neat.com"),
            auth: .generatedAppToken
        )

        let _ = try? await self.airshipSession.performHTTPRequest(request)
        let timeStamp = AirshipDateFormatter.string(fromDate: self.date.now, format: .iso)

        let token = try AirshipUtils.generateSignedToken(
            secret: "testAppSecret",
            tokenParams: ["testAppKey", nonce, timeStamp]
        )

        let authHeaders = [
            "Authorization": "Bearer \(token)",
            "X-UA-Appkey": "testAppKey",
            "X-UA-Nonce": nonce,
            "X-UA-Timestamp": timeStamp
        ]

        let headers = testURLSession.requests.last?.allHTTPHeaderFields?.filter({ (key: String, value: String) in
            authHeaders[key] != nil
        })

        XCTAssertEqual(authHeaders, headers)
    }

    func testGeneratedChannelToken() async throws {
        let request = AirshipRequest(
            url: URL(string: "http://neat.com"),
            auth: .generatedChannelToken(identifier: "some channel")
        )

        let _ = try? await self.airshipSession.performHTTPRequest(request)
        let timeStamp = AirshipDateFormatter.string(fromDate: self.date.now, format: .iso)

        let token = try AirshipUtils.generateSignedToken(
            secret: "testAppSecret",
            tokenParams: ["testAppKey", "some channel", nonce, timeStamp]
        )

        let authHeaders = [
            "Authorization": "Bearer \(token)",
            "X-UA-Appkey": "testAppKey",
            "X-UA-Channel-ID": "some channel",
            "X-UA-Nonce": nonce,
            "X-UA-Timestamp": timeStamp
        ]

        let headers = testURLSession.requests.last?.allHTTPHeaderFields?.filter({ (key: String, value: String) in
            authHeaders[key] != nil
        })

        XCTAssertEqual(authHeaders, headers)
    }

    @MainActor
    func testExpiredChannelAuth() async throws {
        let authProvider = TestAuthTokenProvider() { identifier in
            XCTAssertEqual("some identifier", identifier)
            return "some auth token"
        }

        airshipSession.channelAuthTokenProvider = authProvider

        let request = AirshipRequest(
            url: URL(string: "https://airship.com/something"),
            auth: .channelAuthToken(identifier: "some identifier")
        )

        self.testURLSession.responses = [
            Response.makeResponse(status: 401),
            Response.makeResponse(status: 401)
        ]

        let _ = try? await self.airshipSession.performHTTPRequest(request)

        XCTAssertEqual(2, authProvider.resolveAuthCount)
        XCTAssertEqual(["some auth token", "some auth token"], authProvider.expiredTokens)
    }

    @MainActor
    func testResolveAuthSequentially() async throws {

        // Using a stream to send a result later on
        var escapee: AsyncStream<String>.Continuation!
        let stream = AsyncStream<String>() { continuation in
            escapee = continuation
        }

        let authProvider = TestAuthTokenProvider() { identifier in
            for await token in stream {
                return token
            }
            throw AirshipErrors.error("Failed")
        }

        airshipSession.channelAuthTokenProvider = authProvider

        let request = AirshipRequest(
            url: URL(string: "https://airship.com/something"),
            auth: .channelAuthToken(identifier: "some identifier")
        )

        let airshipSession = self.airshipSession
        await withTaskGroup(of: Void.self) { [escapee] group in
            for _ in 1...4 {
                group.addTask {
                    let _ = try? await airshipSession?.performHTTPRequest(request)
                }
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: 100)
                escapee?.yield("token")
            }
        }

        XCTAssertEqual(1, authProvider.resolveAuthCount)
    }

    @MainActor
    func testNilChannelAuthProviderThrows() async throws {
        let request = AirshipRequest(
            url: URL(string: "http://neat.com"),
            auth: .channelAuthToken(identifier: "some identifier")
        )

        do {
            let _ = try await self.airshipSession.performHTTPRequest(request)
            XCTFail()
        } catch {}
    }

    @MainActor
    func testNilContactAuthProviderThrows() async throws {
        let request = AirshipRequest(
            url: URL(string: "http://neat.com"),
            auth: .contactAuthToken(identifier: "some contact")
        )

        do {
            let _ = try await self.airshipSession.performHTTPRequest(request)
            XCTFail()
        } catch {}
    }

    func testBearerAuth() async throws {
        let request = AirshipRequest(
            url: URL(string: "http://neat.com"),
            auth: .bearer(token: "some token")
        )

        let _ = try? await self.airshipSession.performHTTPRequest(request)

        let auth = testURLSession.requests.last?.allHTTPHeaderFields?[
            "Authorization"
        ]
        XCTAssertEqual("Bearer some token", auth)
    }

    func testBody() async throws {
        let request = AirshipRequest(
            url: URL(string: "http://neat.com"),
            body: "body".data(using: .utf8)
        )

        let _ = try? await self.airshipSession.performHTTPRequest(request)

        let body = testURLSession.requests.last?.httpBody
        XCTAssertEqual(request.body, body)
    }

    func testMethod() async throws {
        let request = AirshipRequest(
            url: URL(string: "http://neat.com"),
            method: "HEAD"
        )

        let _ = try? await self.airshipSession.performHTTPRequest(request)

        let method = testURLSession.requests.last?.httpMethod
        XCTAssertEqual("HEAD", method)
    }

    func testDeflateBody() async throws {
        let request = AirshipRequest(
            url: URL(string: "http://neat.com"),
            body: "body".data(using: .utf8),
            contentEncoding: .deflate
        )

        let _ = try? await self.airshipSession.performHTTPRequest(request)

        let body = testURLSession.requests.last?.httpBody
        XCTAssertEqual(
            "S8pPqQQA",
            body?.base64EncodedString()
        )

        let contentEncoding = testURLSession.requests.last?.allHTTPHeaderFields?["Content-Encoding"]
        XCTAssertEqual("deflate", contentEncoding)
    }

    func testDeflateRoundTrip() throws {
        let testInputs: [Data] = [
            "body".data(using: .utf8)!,
            "Hello, World! This is a test of deflate compression.".data(using: .utf8)!,
            String(repeating: "ABCDEFGHIJ", count: 1000).data(using: .utf8)!,
            Data((0..<256).map { UInt8($0) }),
            "a".data(using: .utf8)!,
        ]

        for (index, input) in testInputs.enumerated() {
            let compressed = try (input as NSData).compressed(using: .zlib) as Data
            let decompressed = try (compressed as NSData).decompressed(using: .zlib) as Data

            XCTAssertEqual(
                input,
                decompressed,
                "Deflate round-trip failed for input \(index) (size \(input.count) bytes)"
            )
        }
    }

    func testRequest() async throws {
        let request = AirshipRequest(
            url: URL(string: "https://airship.com")
        )

        self.testURLSession.responses = [
            Response.makeResponse(status: 301, responseBody: "Neat")
        ]

        let response = try! await self.airshipSession.performHTTPRequest(
            request
        ) {
            data,
            response in
            return String(data: data!, encoding: .utf8)
        }

        XCTAssertEqual("Neat", response.result)
        XCTAssertEqual(301, response.statusCode)
    }

    func testNilURL() async throws {
        let request = AirshipRequest(
            url: nil,
            body: "body".data(using: .utf8),
            contentEncoding: .deflate
        )

        do {
            let _ = try await self.airshipSession.performHTTPRequest(request)
            XCTFail()
        } catch {

        }
    }

    func testParseError() async throws {
        let request = AirshipRequest(
            url: URL(string: "https://airship.com/something")!
        )

        self.testURLSession.responses = [
            Response.makeResponse(status: 301, responseBody: "Neat")
        ]


        do {
            let _ = try await self.airshipSession.performHTTPRequest(request) {
                _,
                _ in
                throw AirshipErrors.error("NEAT!")
            }
            XCTFail()
        } catch {

        }
    }
}


final class TestAuthTokenProvider: AuthTokenProvider, @unchecked Sendable {

    public var resolveAuthCount: Int = 0
    public var expiredTokens: [String] = []
    private let onResolve: (String) async throws -> String
    init(onResolve: @escaping (String) async throws -> String) {
        self.onResolve = onResolve
    }

    func resolveAuth(identifier: String) async throws -> String {
        resolveAuthCount += 1
        return try await self.onResolve(identifier)
    }

    func authTokenExpired(token: String) async {
        expiredTokens.append(token)
    }
}


fileprivate final class TestURLRequestSession: URLRequestSessionProtocol, @unchecked Sendable {

    private let lock = AirshipLock()
    private var _requests: [URLRequest] = []
    var requests: [URLRequest] {
        var result: [URLRequest]!
        lock.sync {
            result = _requests
        }
        return result
    }

    var responses: [Response] = []

    func dataTask(
        request: URLRequest,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> AirshipCancellable {
        lock.sync {
            self._requests.append(request)
        }
        let response = responses.isEmpty ? nil :  responses.removeFirst()
        completionHandler(
            response?.responseBody?.data(using: .utf8),
            response?.httpResponse,
            response?.error
        )

        return CancellableValueHolder<String>() { _ in}
    }
    
}

fileprivate struct Response {
    let httpResponse: HTTPURLResponse?
    let error: Error?
    let responseBody: String?

    init(
        httpResponse: HTTPURLResponse? = nil,
        responseBody: String? = nil,
        error: Error? = nil
    ) {
        self.httpResponse = httpResponse
        self.error = error
        self.responseBody = responseBody
    }

    static func makeError(_ error: Error) -> Response {
        return Response(error: error)
    }

    static func makeResponse(
        status: Int,
        responseHeaders: [String: String]? = nil,
        responseBody: String? = nil
    ) -> Response {
        return Response(
            httpResponse: HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: status,
                httpVersion: nil,
                headerFields: responseHeaders ?? [:]
            )!,
            responseBody: responseBody
        )
    }
}
