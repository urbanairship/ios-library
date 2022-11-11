/* Copyright Airship and Contributors */

import SwiftUI
import XCTest

@testable import AirshipCore

class SubscriptionListAPIClientTest: XCTestCase {

    var config: RuntimeConfig!
    var session: TestRequestSession!
    var client: SubscriptionListAPIClient!

    override func setUpWithError() throws {
        let airshipConfig = Config()
        airshipConfig.requireInitialRemoteConfigEnabled = false
        self.config = RuntimeConfig(
            config: airshipConfig,
            dataStore: PreferenceDataStore(appKey: UUID().uuidString)
        )
        self.session = TestRequestSession.init()
        self.client = SubscriptionListAPIClient(
            config: self.config,
            session: self.session
        )
    }

    func testGet() throws {
        let responseBody = """
                {
                   "ok" : true,
                   "list_ids": ["example_listId-1","example_listId-2"]
                }
            """

        self.session.response = HTTPURLResponse(
            url: URL(string: "https://neat")!,
            statusCode: 200,
            httpVersion: "",
            headerFields: [String: String]()
        )
        self.session.data = responseBody.data(using: .utf8)

        let expectation = XCTestExpectation(description: "callback called")

        self.client.get(channelID: "some-channel") { response, error in
            XCTAssertEqual(response?.status, 200)
            XCTAssertNil(error)
            XCTAssertEqual(
                ["example_listId-1", "example_listId-2"],
                response?.listIDs
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)

        XCTAssertEqual("GET", self.session.lastRequest?.method)
        XCTAssertEqual(
            "https://device-api.urbanairship.com/api/subscription_lists/channels/some-channel",
            self.session.lastRequest?.url?.absoluteString
        )
    }

    func testGetParseError() throws {
        let responseBody = "What?"

        self.session.response = HTTPURLResponse(
            url: URL(string: "https://neat")!,
            statusCode: 200,
            httpVersion: "",
            headerFields: [String: String]()
        )
        self.session.data = responseBody.data(using: .utf8)

        let expectation = XCTestExpectation(description: "callback called")

        self.client.get(channelID: "some-channel") { response, error in
            XCTAssertNotNil(error)
            XCTAssertNil(response)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func testGetError() throws {
        let sessionError = AirshipErrors.error("error!")
        self.session.error = sessionError

        let expectation = XCTestExpectation(description: "callback called")

        self.client.get(channelID: "some-channel") { response, error in
            XCTAssertEqual(sessionError as NSError, error! as NSError)
            XCTAssertNil(response)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }
}
