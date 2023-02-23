/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

final class AirshipRequestSessionTest: AirshipBaseTest {

    private let testURLSession = TestURLRequestSession()
    private var airshipSession: AirshipRequestSession!

    override func setUpWithError() throws {
        self.airshipSession = AirshipRequestSession(
            appKey: self.config.appKey,
            session: self.testURLSession
        )
    }

    func testDefaultHeaders() async throws {
        let request = AirshipRequest(url: URL(string: "http://neat.com"))

        let _ = try? await self.airshipSession.performHTTPRequest(request) {
            _,
            _ in
            return false
        }

        let headers = testURLSession.lastRequest?.allHTTPHeaderFields
        let expected = [
            "Accept-Encoding": "gzip;q=1.0, compress;q=0.5",
            "User-Agent": "(UALib \(AirshipVersion.get()); \(self.config.appKey))",
            "X-UA-App-Key": self.config.appKey,
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

        let _ = try? await self.airshipSession.performHTTPRequest(request) {
            _,
            _ in
            return false
        }

        let headers = testURLSession.lastRequest?.allHTTPHeaderFields
        let expected = [
            "foo": "bar",
            "Accept-Encoding": "gzip;q=1.0, compress;q=0.5",
            "User-Agent": "Something else",
            "X-UA-App-Key": self.config.appKey,
        ]

        XCTAssertEqual(expected, headers)
    }

    func testBasicAuth() async throws {
        let request = AirshipRequest(
            url: URL(string: "http://neat.com"),
            auth: .basic("name", "password")
        )

        let _ = try? await self.airshipSession.performHTTPRequest(request) {
            _,
            _ in
            return false
        }

        let auth = testURLSession.lastRequest?.allHTTPHeaderFields?[
            "Authorization"
        ]
        XCTAssertEqual("Basic bmFtZTpwYXNzd29yZA==", auth)
    }
    
    func testBearerAuth() async throws {
        let request = AirshipRequest(
            url: URL(string: "http://neat.com"),
            auth: .bearer(self.config.appSecret, self.config.appKey, "channel ID")
        )

        let _ = try? await self.airshipSession.performHTTPRequest(request) {
            _,
            _ in
            return false
        }

        let auth = testURLSession.lastRequest?.allHTTPHeaderFields?[
            "Authorization"
        ]
        XCTAssertEqual("Bearer  Npyqy5OZxMEVv4bt64S3aUE4NwUQVLX50vGrEegohFE=", auth)
    }

    func testBody() async throws {
        let request = AirshipRequest(
            url: URL(string: "http://neat.com"),
            body: "body".data(using: .utf8)
        )

        let _ = try? await self.airshipSession.performHTTPRequest(request) {
            _,
            _ in
            return false
        }

        let body = testURLSession.lastRequest?.httpBody
        XCTAssertEqual(request.body, body)
    }

    func testMethod() async throws {
        let request = AirshipRequest(
            url: URL(string: "http://neat.com"),
            method: "HEAD"
        )

        let _ = try? await self.airshipSession.performHTTPRequest(request) {
            _,
            _ in
            return false
        }

        let method = testURLSession.lastRequest?.httpMethod
        XCTAssertEqual("HEAD", method)
    }

    func testGZIPBody() async throws {
        let request = AirshipRequest(
            url: URL(string: "http://neat.com"),
            body: "body".data(using: .utf8),
            compressBody: true
        )

        let _ = try? await self.airshipSession.performHTTPRequest(request) {
            _,
            _ in
            return false
        }

        let body = testURLSession.lastRequest?.httpBody
        XCTAssertEqual(
            "H4sIAAAAAAAAE0vKT6kEALILqNsEAAAA",
            body?.base64EncodedString()
        )
    }

    func testRequest() async throws {
        let request = AirshipRequest(
            url: URL(string: "https://airship.com")
        )

        self.testURLSession.response = HTTPURLResponse(
            url: URL(string: "https://airship.com/something")!,
            statusCode: 301,
            httpVersion: nil,
            headerFields: nil
        )

        self.testURLSession.responseBody = "Neat"

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
            compressBody: true
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

        self.testURLSession.response = HTTPURLResponse(
            url: URL(string: "https://airship.com/something")!,
            statusCode: 301,
            httpVersion: nil,
            headerFields: nil
        )

        self.testURLSession.responseBody = "Neat"

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

class TestURLRequestSession: URLRequestSessionProtocol {

    private(set) var lastRequest: URLRequest?

    var responseBody: String?
    var response: HTTPURLResponse?
    var error: Error?

    func dataTask(
        request: URLRequest,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> AirshipCancellable {
        self.lastRequest = request

        completionHandler(
            self.responseBody?.data(using: .utf8),
            self.response,
            self.error
        )

        return CancellabelValueHolder<String>() { _ in}
    }
}
