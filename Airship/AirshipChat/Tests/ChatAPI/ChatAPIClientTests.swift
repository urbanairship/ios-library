/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipChat
import AirshipCore

class HTTPChatAPIClientTests: XCTestCase {
    var requestSession: MockHTTPRequestSession!
    var appKey: String!
    var client: ChatAPIClient!

    override func setUp() {
        super.setUp()
        self.appKey = UUID().uuidString
        self.requestSession = MockHTTPRequestSession()
        self.client = ChatAPIClient(session: self.requestSession)
    }

    func testURL() throws {
        let expectation = XCTestExpectation(description: "Callback")
        self.client.createUVP(appKey: self.appKey, channelID: "some-channel") { _,_ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)

        let expected = "https://wwrni3iy87.execute-api.us-west-1.amazonaws.com/Prod/api/UVP?channelId=some-channel&appKey=\(self.appKey!)&platform=iOS"

        XCTAssertEqual(expected, self.requestSession.lastRequest?.url?.absoluteString)
    }

    func test200() throws {
        self.requestSession.response =  HTTPURLResponse(url: URL(string: "https://neat")!,
                                                        statusCode: 200,
                                                        httpVersion: "ANYTHING",
                                                        headerFields: [String: String]())

        self.requestSession.responseBody = """
        {
            "uvp": "SOME UVP"
        }
        """

        let expectation = XCTestExpectation(description: "Callback")
        self.client.createUVP(appKey: self.appKey, channelID: "some-channel") { (response, error) in
            XCTAssertNil(error)
            XCTAssertEqual(200, response?.status)
            XCTAssertEqual("SOME UVP", response?.uvp)

            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }

    func testParseError() throws {
        self.requestSession.response =  HTTPURLResponse(url: URL(string: "https://neat")!,
                                                        statusCode: 200,
                                                        httpVersion: "ANYTHING",
                                                        headerFields: [String: String]())

        self.requestSession.responseBody = """
        {
            "not the UVP": "SOME UVP"
        }
        """

        let expectation = XCTestExpectation(description: "Callback")
        self.client.createUVP(appKey: self.appKey, channelID: "some-channel") { (response, error) in
            XCTAssertNotNil(error)
            XCTAssertNil(response)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func testError() throws {
        self.requestSession.error = NSError(domain: "domain", code: 10, userInfo: nil)

        let expectation = XCTestExpectation(description: "Callback")
        self.client.createUVP(appKey: self.appKey, channelID: "some-channel") { (response, error) in
            XCTAssertNotNil(error)
            XCTAssertNil(response)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func testFailure() throws {
        self.requestSession.response =  HTTPURLResponse(url: URL(string: "https://neat")!,
                                                        statusCode: 400,
                                                        httpVersion: "ANYTHING",
                                                        headerFields: [String: String]())

        let expectation = XCTestExpectation(description: "Callback")
        self.client.createUVP(appKey: self.appKey, channelID: "some-channel") { (response, error) in
            XCTAssertNil(error)
            XCTAssertEqual(400, response?.status)
            XCTAssertNil(response?.uvp)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }
}
