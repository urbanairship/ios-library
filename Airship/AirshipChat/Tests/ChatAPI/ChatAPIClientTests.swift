/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipChat
import AirshipCore

class HTTPChatAPIClientTests: XCTestCase {
    var mockSession: MockHTTPRequestSession!
    var mockConfig: MockChatConfig!
    var client: ChatAPIClient!

    override func setUp() {
        super.setUp()
        self.mockSession = MockHTTPRequestSession()
        self.mockConfig = MockChatConfig(appKey: "someAppKey",
                                         chatURL: "https://test",
                                         chatWebSocketURL: "wss:test")

        self.client = ChatAPIClient(chatConfig: self.mockConfig, session: self.mockSession)
    }

    func testURL() throws {
        let expectation = XCTestExpectation(description: "Callback")
        self.client.createUVP(channelID: "some-channel") { _,_ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)

        let expected = "https://test/api/UVP?channelId=some-channel&appKey=\(self.mockConfig.appKey)&platform=iOS"

        XCTAssertEqual(expected, self.mockSession.lastRequest?.url?.absoluteString)
    }

    func test200() throws {
        self.mockSession.response =  HTTPURLResponse(url: URL(string: "https://neat")!,
                                                        statusCode: 200,
                                                        httpVersion: "ANYTHING",
                                                        headerFields: [String: String]())

        self.mockSession.responseBody = """
        {
            "uvp": "SOME UVP"
        }
        """

        let expectation = XCTestExpectation(description: "Callback")
        self.client.createUVP(channelID: "some-channel") { (response, error) in
            XCTAssertNil(error)
            XCTAssertEqual(200, response?.status)
            XCTAssertEqual("SOME UVP", response?.uvp)

            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }

    func testParseError() throws {
        self.mockSession.response =  HTTPURLResponse(url: URL(string: "https://neat")!,
                                                        statusCode: 200,
                                                        httpVersion: "ANYTHING",
                                                        headerFields: [String: String]())

        self.mockSession.responseBody = """
        {
            "not the UVP": "SOME UVP"
        }
        """

        let expectation = XCTestExpectation(description: "Callback")
        self.client.createUVP(channelID: "some-channel") { (response, error) in
            XCTAssertNotNil(error)
            XCTAssertNil(response)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func testError() throws {
        self.mockSession.error = NSError(domain: "domain", code: 10, userInfo: nil)

        let expectation = XCTestExpectation(description: "Callback")
        self.client.createUVP(channelID: "some-channel") { (response, error) in
            XCTAssertNotNil(error)
            XCTAssertNil(response)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func testFailure() throws {
        self.mockSession.response =  HTTPURLResponse(url: URL(string: "https://neat")!,
                                                        statusCode: 400,
                                                        httpVersion: "ANYTHING",
                                                        headerFields: [String: String]())

        let expectation = XCTestExpectation(description: "Callback")
        self.client.createUVP(channelID: "some-channel") { (response, error) in
            XCTAssertNil(error)
            XCTAssertEqual(400, response?.status)
            XCTAssertNil(response?.uvp)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }
}
