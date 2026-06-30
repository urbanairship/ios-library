/* Copyright Airship and Contributors */

import Testing

@_spi(AirshipInternal) import AirshipBasement
@testable
import AirshipCore
import Foundation

@Suite
struct RemoteDataAPIClientTest {
    let config: RuntimeConfig = RuntimeConfig.testConfig()

    let remoteDataAPIClient: RemoteDataAPIClient
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

    init() {
        self.remoteDataAPIClient = RemoteDataAPIClient(
            config: self.config,
            session: self.testSession
        )
    }

    @Test
    func testFetch() async throws {
        self.testSession.response = HTTPURLResponse(
            url: URL(string: "https://neat")!,
            statusCode: 200,
            httpVersion: "",
            headerFields: ["Last-Modified": "new last modified"]
        )
        self.testSession.data = RemoteDataAPIClientTest.validResponse.data(using: .utf8)

        let exampleURL = self.exampleURL
        let response = try await self.remoteDataAPIClient.fetchRemoteData(
            url: exampleURL,
            auth: .contactAuthToken(identifier: "some contact ID"),
            lastModified: "current last modified"
        ) { lastModified in
            #expect(lastModified == "new last modified")
            return RemoteDataInfo(url: exampleURL, lastModifiedTime: lastModified, source: .contact)
        }

        let expectedResult = RemoteDataResult(
            payloads: [
                RemoteDataPayload(
                    type: "test_data_type",
                    timestamp: AirshipDateFormatter.date(from: "2017-01-01T12:00:00")!,
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
            "X-UA-Appkey": "\(config.appCredentials.appKey)",
            "If-Modified-Since": "current last modified",
            "Accept": "application/vnd.urbanairship+json; version=3;"
        ]

        #expect(200 == response.statusCode)
        #expect(expectedResult == response.result)

        #expect("GET" == self.testSession.lastRequest?.method)
        #expect(self.exampleURL == self.testSession.lastRequest?.url)
        #expect(expectedHeaders == self.testSession.lastRequest?.headers)
        #expect(AirshipRequestAuth.contactAuthToken(identifier: "some contact ID") == self.testSession.lastRequest?.auth)
    }

    @Test
    func testFetch304() async throws {
        self.testSession.response = HTTPURLResponse(
            url: URL(string: "https://neat")!,
            statusCode: 304,
            httpVersion: "",
            headerFields: ["Last-Modified": "new last modified"]
        )

        let exampleURL = self.exampleURL
        let response = try await self.remoteDataAPIClient.fetchRemoteData(
            url: self.exampleURL,
            auth: .contactAuthToken(identifier: "some contact ID"),
            lastModified: "current last modified"
        ) { lastModified in
            Issue.record("Should not be reached")
            return RemoteDataInfo(url: exampleURL, lastModifiedTime: lastModified, source: .contact)
        }

        #expect(304 == response.statusCode)
        #expect(response.result == nil)
    }

    @Test
    func testEmptyResponse() async throws {
        self.testSession.response = HTTPURLResponse(
            url: URL(string: "https://neat")!,
            statusCode: 200,
            httpVersion: "",
            headerFields: ["Last-Modified": "new last modified"]
        )

        self.testSession.data = "{ \"ok\": true }".data(using: .utf8)

        let exampleURL = self.exampleURL
        let response = try await self.remoteDataAPIClient.fetchRemoteData(
            url: self.exampleURL,
            auth: .contactAuthToken(identifier: "some contact ID"),
            lastModified: "current last modified"
        ) { lastModified in
            return RemoteDataInfo(url: exampleURL, lastModifiedTime: lastModified, source: .contact)
        }

        let expectedResult = RemoteDataResult(
            payloads: [],
            remoteDataInfo: RemoteDataInfo(
                url: self.exampleURL,
                lastModifiedTime: "new last modified",
                source: .contact
            )
        )

        #expect(200 == response.statusCode)
        #expect(expectedResult == response.result)
    }

    @Test
    func testNoLastModified() async throws {
        self.testSession.response = HTTPURLResponse(
            url: URL(string: "https://neat")!,
            statusCode: 200,
            httpVersion: "",
            headerFields: [:]
        )

        self.testSession.data = "{ \"ok\": true }".data(using: .utf8)

        let exampleURL = self.exampleURL
        let response = try await self.remoteDataAPIClient.fetchRemoteData(
            url: self.exampleURL,
            auth: .basicAppAuth,
            lastModified: nil
        ) { lastModified in
            #expect(lastModified == nil)
            return RemoteDataInfo(url: exampleURL, lastModifiedTime: lastModified, source: .app)
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
            "X-UA-Appkey": config.appCredentials.appKey,
            "Accept": "application/vnd.urbanairship+json; version=3;"
        ]

        #expect(200 == response.statusCode)
        #expect(expectedResult == response.result)
        #expect(expectedHeaders == self.testSession.lastRequest?.headers)
    }

}
