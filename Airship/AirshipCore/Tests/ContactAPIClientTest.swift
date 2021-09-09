/* Copyright Airship and Contributors */

import XCTest
@testable
import AirshipCore

class ContactAPIClientTest: XCTestCase {
    
    var config: RuntimeConfig!
    var session: TestRequestSession!
    var contactAPIClient: ContactAPIClient!

    override func setUpWithError() throws {
        self.config = RuntimeConfig(config: Config(), dataStore: PreferenceDataStore(keyPrefix: UUID().uuidString))
        self.session = TestRequestSession.init()
        self.session.response = HTTPURLResponse(url: URL(string: "https://contacts_test")!,
                                           statusCode: 200,
                                           httpVersion: "",
                                           headerFields: [String: String]())
        
        self.contactAPIClient = ContactAPIClient.init(config: self.config, session: self.session)
    }
    
    func testIdentify() throws {
        self.session.data = """
        {
            "contact_id": "56779"
        }
        """.data(using: .utf8)
        
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
        
        let expectation = XCTestExpectation(description: "callback called")
        
        contactAPIClient.reset(channelID: "test_channel") { response, error in
            XCTAssertEqual(response?.status, 200)
            XCTAssertNil(error)
            XCTAssertNotNil(response?.contactID)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testUpdate() throws {
        let tagUpdates = [
            TagGroupUpdate(group: "tag-set", tags: [], type: .set),
            TagGroupUpdate(group: "tag-add", tags: ["add tag"], type: .add),
            TagGroupUpdate(group: "tag-other-add", tags: ["other tag"], type: .add),
            TagGroupUpdate(group: "tag-remove", tags: ["remove tag"], type: .remove)
        ]
        
        let date = Date()
        let attributeUpdates = [
            AttributeUpdate.set(attribute: "some-string", value: "Hello", date: date),
            AttributeUpdate.set(attribute: "some-number", value: 32.0, date: date),
            AttributeUpdate.remove(attribute: "some-remove", date: date)
        ]
        
        let expectation = XCTestExpectation(description: "callback called")
        contactAPIClient.update(identifier: "some-contact-id", tagGroupUpdates: tagUpdates, attributeUpdates: attributeUpdates) { response, error in
            XCTAssertEqual(response?.status, 200)
            XCTAssertNil(error)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        let request = self.session.lastRequest!
        XCTAssertEqual("https://device-api.urbanairship.com/api/contacts/some-contact-id", request.url!.absoluteString)
        
        let body = try JSONSerialization.jsonObject(with: request.body!, options: [])
        let formattedDate = Utils.isoDateFormatterUTCWithDelimiter().string(from: date)
        let expectedBody : Any = [
            "attributes" : [
                [
                    "action" : "set",
                    "key" : "some-string",
                    "timestamp" : formattedDate,
                    "value" : "Hello"
                ],
                [
                    "action" : "set",
                    "key" : "some-number",
                    "timestamp" : formattedDate,
                    "value" : 32
                ],
                [
                    "action" : "remove",
                    "key" : "some-remove",
                    "timestamp" : formattedDate,
                ],
            ],
            "tags": [
                "add": [
                    "tag-add": [
                        "add tag"
                    ],
                    "tag-other-add": [
                        "other tag"
                    ]
                ],
                "remove": [
                    "tag-remove": [
                        "remove tag"
                    ]
                ],
                "set": [
                    "tag-set": [
                    ]
                ]
            ]
        ]
        
        XCTAssertEqual(body as! NSDictionary, expectedBody as! NSDictionary)
    }

}
