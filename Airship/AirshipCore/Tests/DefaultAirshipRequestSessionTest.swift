/* Copyright Airship and Contributors */

import Testing
import Foundation

@_spi(AirshipInternal) import AirshipBasement
@_spi(AirshipInternal) @testable import AirshipCore

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct DefaultAirshipRequestSessionTest {

    private let testURLSession = TestURLRequestSession()
    private var airshipSession: DefaultAirshipRequestSession!
    private let nonce: String = UUID().uuidString

    private let date: UATestDate = UATestDate(offset: 0, dateOverride: Date())

    init() {
        let nonce = self.nonce
        self.airshipSession = DefaultAirshipRequestSession(
            appKey: "testAppKey",
            appSecret: "testAppSecret",
            session: self.testURLSession,
            date: date
        ) {
            return nonce
        }
    }

    @Test
    func testDefaultHeaders() async throws {
        let request = AirshipRequest(url: URL(string: "http://neat.com"))

        let _ = try? await self.airshipSession.performHTTPRequest(request)

        let headers = testURLSession.requests.last?.allHTTPHeaderFields
        let expected = [
            "Accept-Encoding": "gzip;q=1.0, compress;q=0.5",
            "User-Agent": "(UALib \(AirshipVersion.version); testAppKey)",
            "X-UA-App-Key": "testAppKey",
        ]

        #expect(expected == headers)
    }

    @Test
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

        #expect(expected == headers)
    }

    @Test
    func testBasicAuth() async throws {
        let request = AirshipRequest(
            url: URL(string: "http://neat.com"),
            auth: .basic(username: "name", password: "password")
        )

        let _ = try? await self.airshipSession.performHTTPRequest(request)

        let auth = testURLSession.requests.last?.allHTTPHeaderFields?[
            "Authorization"
        ]
        #expect("Basic bmFtZTpwYXNzd29yZA==" == auth)
    }

    @Test
    func testAppAuth() async throws {
        let request = AirshipRequest(
            url: URL(string: "http://neat.com"),
            auth: .basicAppAuth
        )

        let _ = try? await self.airshipSession.performHTTPRequest(request)

        let auth = testURLSession.requests.last?.allHTTPHeaderFields?[
            "Authorization"
        ]
        #expect("Basic dGVzdEFwcEtleTp0ZXN0QXBwU2VjcmV0" == auth)
    }

    @Test
    @MainActor
    func testChannelAuthToken() async throws {
        let authProvider = TestAuthTokenProvider() { identifier in
            #expect("some identifier" == identifier)
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

        #expect(authHeaders == headers)
    }

    @Test
    @MainActor
    func testContactAuthToken() async throws {
        let authProvider = TestAuthTokenProvider() { identifier in
            #expect("some contact" == identifier)
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

        #expect(authHeaders == headers)
    }

    @Test
    func testGeneratedAppToken() async throws {
        let request = AirshipRequest(
            url: URL(string: "http://neat.com"),
            auth: .generatedAppToken
        )

        let _ = try? await self.airshipSession.performHTTPRequest(request)
        let timeStamp = AirshipDateFormatter.string(fromDate: self.date.now, format: .iso8601)

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

        #expect(authHeaders == headers)
    }

    @Test
    func testGeneratedChannelToken() async throws {
        let request = AirshipRequest(
            url: URL(string: "http://neat.com"),
            auth: .generatedChannelToken(identifier: "some channel")
        )

        let _ = try? await self.airshipSession.performHTTPRequest(request)
        let timeStamp = AirshipDateFormatter.string(fromDate: self.date.now, format: .iso8601)

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

        #expect(authHeaders == headers)
    }

    @Test
    @MainActor
    func testExpiredChannelAuth() async throws {
        let authProvider = TestAuthTokenProvider() { identifier in
            #expect("some identifier" == identifier)
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

        #expect(2 == authProvider.resolveAuthCount)
        #expect(["some auth token", "some auth token"] == authProvider.expiredTokens)
    }

    @Test
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

        #expect(1 == authProvider.resolveAuthCount)
    }

    @Test
    @MainActor
    func testNilChannelAuthProviderThrows() async throws {
        let request = AirshipRequest(
            url: URL(string: "http://neat.com"),
            auth: .channelAuthToken(identifier: "some identifier")
        )

        do {
            let _ = try await self.airshipSession.performHTTPRequest(request)
            Issue.record("Should throw")
        } catch {}
    }

    @Test
    @MainActor
    func testNilContactAuthProviderThrows() async throws {
        let request = AirshipRequest(
            url: URL(string: "http://neat.com"),
            auth: .contactAuthToken(identifier: "some contact")
        )

        do {
            let _ = try await self.airshipSession.performHTTPRequest(request)
            Issue.record("Should throw")
        } catch {}
    }

    @Test
    func testBearerAuth() async throws {
        let request = AirshipRequest(
            url: URL(string: "http://neat.com"),
            auth: .bearer(token: "some token")
        )

        let _ = try? await self.airshipSession.performHTTPRequest(request)

        let auth = testURLSession.requests.last?.allHTTPHeaderFields?[
            "Authorization"
        ]
        #expect("Bearer some token" == auth)
    }

    @Test
    func testBody() async throws {
        let request = AirshipRequest(
            url: URL(string: "http://neat.com"),
            body: "body".data(using: .utf8)
        )

        let _ = try? await self.airshipSession.performHTTPRequest(request)

        let body = testURLSession.requests.last?.httpBody
        #expect(request.body == body)
    }

    @Test
    func testMethod() async throws {
        let request = AirshipRequest(
            url: URL(string: "http://neat.com"),
            method: "HEAD"
        )

        let _ = try? await self.airshipSession.performHTTPRequest(request)

        let method = testURLSession.requests.last?.httpMethod
        #expect("HEAD" == method)
    }

    @Test
    func testDeflateBody() async throws {
        let request = AirshipRequest(
            url: URL(string: "http://neat.com"),
            body: "body".data(using: .utf8),
            contentEncoding: .deflate
        )

        let _ = try? await self.airshipSession.performHTTPRequest(request)

        let body = testURLSession.requests.last?.httpBody
        #expect(
            "S8pPqQQA" ==
            body?.base64EncodedString()
        )

        let contentEncoding = testURLSession.requests.last?.allHTTPHeaderFields?["Content-Encoding"]
        #expect("deflate" == contentEncoding)
    }

    @Test
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

            #expect(
                input ==
                decompressed,
                "Deflate round-trip failed for input \(index) (size \(input.count) bytes)"
            )
        }
    }

    @Test
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

        #expect("Neat" == response.result)
        #expect(301 == response.statusCode)
    }

    @Test
    func testNilURL() async throws {
        let request = AirshipRequest(
            url: nil,
            body: "body".data(using: .utf8),
            contentEncoding: .deflate
        )

        do {
            let _ = try await self.airshipSession.performHTTPRequest(request)
            Issue.record("Should throw")
        } catch {

        }
    }

    @Test
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
            Issue.record("Should throw")
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
