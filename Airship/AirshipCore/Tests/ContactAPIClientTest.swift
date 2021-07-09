/* Copyright Airship and Contributors */

import XCTest
@testable
import AirshipCore

class ContactAPIClientTest: XCTestCase {
    
    var config: UARuntimeConfig!
    var session: TestRequestSession!

    override func setUpWithError() throws {
        self.config = UARuntimeConfig.init()
        self.session = TestRequestSession.init()
        self.session.response = HTTPURLResponse(url: URL(string: "https://contacts_test")!,
                                           statusCode: 200,
                                           httpVersion: "",
                                           headerFields: [String: String]())
    }
    
    func testIdentify() throws {
        self.session.data = """
        {
            "contact_id": "56779"
        }
        """.data(using: .utf8)
        
        let contactAPIClient = ContactAPIClient.init(config: self.config, session: self.session)
        let expectation = XCTestExpectation(description: "callback called")
        
        contactAPIClient.identify(channelID: "test_channel", namedUserID: "contact", contactID: nil) { response, error in
            XCTAssertEqual(response?.status, 200)
            XCTAssertNil(error)
            XCTAssertNotNil(response?.contactID)
            XCTAssertNotNil(response?.isAnonymous)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    func testResolve() throws {
        self.session.data = """
        {
            "contact_id": "56779",
            "is_anonymous": true
        }
        """.data(using: .utf8)
        
        let contactAPIClient = ContactAPIClient.init(config: self.config, session: self.session)
        let expectation = XCTestExpectation(description: "callback called")
        
        contactAPIClient.resolve(channelID: "test_channel") { response, error in
            XCTAssertEqual(response?.status, 200)
            XCTAssertNil(error)
            XCTAssertNotNil(response?.contactID)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    func testReset() throws {
        self.session.data = """
        {
            "contact_id": "56779",
        }
        """.data(using: .utf8)
        
        let contactAPIClient = ContactAPIClient.init(config: self.config, session: self.session)
        let expectation = XCTestExpectation(description: "callback called")
        
        contactAPIClient.reset(channelID: "test_channel") { response, error in
            XCTAssertEqual(response?.status, 200)
            XCTAssertNil(error)
            XCTAssertNotNil(response?.contactID)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }

}
