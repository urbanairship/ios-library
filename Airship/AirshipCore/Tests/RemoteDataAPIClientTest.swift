/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class RemoteDataAPIClientTest: AirshipBaseTest {
    var remoteDataAPIClient: RemoteDataAPIClient!
    private let testSession: TestAirshipRequestSession = TestAirshipRequestSession()

    private static let validData = """
         {
            "message_center":{
               "background_color":"0000FF",
               "font":"Comic Sans"
            }
         }
    """

    private static let validResponse = """
        {
           "ok":true,
           "payloads":[
              {
                 "type":"test_data_type",
                 "timestamp":"2017-01-01T12:00:00",
                 "data":\(validData)
              }
           ]
        }
    """

    private let exampleURL: URL = URL(string: "exampleurl://")!

    override func setUpWithError() throws {
        self.remoteDataAPIClient = RemoteDataAPIClient(
            config: self.config,
            session: self.testSession
        )
    }

    func testFetch() async throws {
        self.testSession.response = HTTPURLResponse(
            url: URL(string: "https://neat")!,
            statusCode: 200,
            httpVersion: "",
            headerFields: ["Last-Modified": "new last modified"]
        )
        self.testSession.data = RemoteDataAPIClientTest.validResponse.data(using: .utf8)

        let response = try await self.remoteDataAPIClient.fetchRemoteData(
            url: self.exampleURL,
            auth: .contactAuthToken(identifier: "some contact ID"),
            lastModified: "current last modified"
        ) { lastModified in
            XCTAssertEqual(lastModified, "new last modified")
            return RemoteDataInfo(url: self.exampleURL, lastModifiedTime: lastModified, source: .contact)
        }

        let expectedResult = RemoteDataResult(
            payloads: [
                RemoteDataPayload(
                    type: "test_data_type",
                    timestamp: AirshipUtils.parseISO8601Date(from: "2017-01-01T12:00:00")!,
                    data: try! AirshipJSON.from(json: RemoteDataAPIClientTest.validData),
                    remoteDataInfo: RemoteDataInfo(
                        url: self.exampleURL,
                        lastModifiedTime: "new last modified",
                        source: .contact
                    )
                )
            ],
            remoteDataInfo: RemoteDataInfo(
                url: self.exampleURL,
                lastModifiedTime: "new last modified",
                source: .contact
            )
        )

        let expectedHeaders = [
            "X-UA-Appkey": "test-app-key",
            "If-Modified-Since": "current last modified",
            "Accept": "application/vnd.urbanairship+json; version=3;"
        ]

        XCTAssertEqual(200, response.statusCode)
        XCTAssertEqual(expectedResult, response.result)

        XCTAssertEqual("GET", self.testSession.lastRequest?.method)
        XCTAssertEqual(self.exampleURL, self.testSession.lastRequest?.url)
        XCTAssertEqual(expectedHeaders, self.testSession.lastRequest?.headers)
        XCTAssertEqual(AirshipRequestAuth.contactAuthToken(identifier: "some contact ID"), self.testSession.lastRequest?.auth)
    }

    func testFetch304() async throws {
        self.testSession.response = HTTPURLResponse(
            url: URL(string: "https://neat")!,
            statusCode: 304,
            httpVersion: "",
            headerFields: ["Last-Modified": "new last modified"]
        )

        let response = try await self.remoteDataAPIClient.fetchRemoteData(
            url: self.exampleURL,
            auth: .contactAuthToken(identifier: "some contact ID"),
            lastModified: "current last modified"
        ) { lastModified in
            XCTFail("Should not be reached")
            return RemoteDataInfo(url: self.exampleURL, lastModifiedTime: lastModified, source: .contact)
        }

        XCTAssertEqual(304, response.statusCode)
        XCTAssertNil(response.result)
    }

    func testEmptyResponse() async throws {
        self.testSession.response = HTTPURLResponse(
            url: URL(string: "https://neat")!,
            statusCode: 200,
            httpVersion: "",
            headerFields: ["Last-Modified": "new last modified"]
        )

        self.testSession.data = "{ \"ok\": true }".data(using: .utf8)

        let response = try await self.remoteDataAPIClient.fetchRemoteData(
            url: self.exampleURL,
            auth: .contactAuthToken(identifier: "some contact ID"),
            lastModified: "current last modified"
        ) { lastModified in
            return RemoteDataInfo(url: self.exampleURL, lastModifiedTime: lastModified, source: .contact)
        }

        let expectedResult = RemoteDataResult(
            payloads: [],
            remoteDataInfo: RemoteDataInfo(
                url: self.exampleURL,
                lastModifiedTime: "new last modified",
                source: .contact
            )
        )

        XCTAssertEqual(200, response.statusCode)
        XCTAssertEqual(expectedResult, response.result)
    }

    func testNoLastModified() async throws {
        self.testSession.response = HTTPURLResponse(
            url: URL(string: "https://neat")!,
            statusCode: 200,
            httpVersion: "",
            headerFields: [:]
        )

        self.testSession.data = "{ \"ok\": true }".data(using: .utf8)

        let response = try await self.remoteDataAPIClient.fetchRemoteData(
            url: self.exampleURL,
            auth: .basicAppAuth,
            lastModified: nil
        ) { lastModified in
            XCTAssertNil(lastModified)
            return RemoteDataInfo(url: self.exampleURL, lastModifiedTime: lastModified, source: .app)
        }

        let expectedResult = RemoteDataResult(
            payloads: [],
            remoteDataInfo: RemoteDataInfo(
                url: self.exampleURL,
                lastModifiedTime: nil,
                source: .app
            )
        )

        let expectedHeaders = [
            "X-UA-Appkey": "test-app-key",
            "Accept": "application/vnd.urbanairship+json; version=3;"
        ]

        XCTAssertEqual(200, response.statusCode)
        XCTAssertEqual(expectedResult, response.result)
        XCTAssertEqual(expectedHeaders, self.testSession.lastRequest?.headers)
    }

}
