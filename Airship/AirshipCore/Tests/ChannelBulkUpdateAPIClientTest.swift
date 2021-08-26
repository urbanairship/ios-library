/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

class ChannelBulkUpdateAPIClientTest: XCTestCase {

    var config: RuntimeConfig!
    var session: TestRequestSession!
    var client: ChannelBulkUpdateAPIClient!

    override func setUpWithError() throws {
        self.config = RuntimeConfig(config: Config(), dataStore: UAPreferenceDataStore(keyPrefix: UUID().uuidString))
        self.session = TestRequestSession.init()
        self.client = ChannelBulkUpdateAPIClient(config: self.config, session: self.session)
    }

    func testUpdate() throws {
        let date = Date()
        self.session.response = HTTPURLResponse(url: URL(string: "https://neat")!,
                                                  statusCode: 200,
                                                  httpVersion: "",
                                                  headerFields: [String: String]())

        let expectation = XCTestExpectation(description: "callback called")

        let subscriptionUpdates = [
            SubscriptionListUpdate(listId: "coffee", type: .unsubscribe),
            SubscriptionListUpdate(listId: "pizza", type: .subscribe)
        ]
        
        let tagUpdates = [
            TagGroupUpdate(group: "some-group", tags: ["tag-1", "tag-2"], type: .add),
            TagGroupUpdate(group: "some-other-group", tags: ["tag-3", "tag-4"], type: .set)
        ]
        
        let attributeUpdates = [
            AttributeUpdate(attribute: "some-attribute", type: .set, value: "hello", date: date)
        ]

        self.client.update(channelID: "some-channel", subscriptionListUpdates: subscriptionUpdates, tagGroupUpdates: tagUpdates, attributeUpdates: attributeUpdates) { response, error in
            XCTAssertEqual(response?.status, 200)
            XCTAssertNil(error)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)

        let expectedBody = [
            "subscription_lists": [
                [
                    "action": "subscribe",
                    "list_id": "pizza",
                ],
                [
                    "action": "unsubscribe",
                    "list_id": "coffee",
                ]
            ],
            "tags": [
                "add": [
                    "some-group": ["tag-1", "tag-2"]
                ],
                "set": [
                    "some-other-group": ["tag-3", "tag-4"]
                ]
            ],
            "attributes": [
                [
                    "action": "set",
                    "key": "some-attribute",
                    "timestamp": UAUtils.isoDateFormatterUTCWithDelimiter().string(from: date),
                    "value": "hello",
                ]
            ]
        ] as NSDictionary

        let lastRequest = self.session.lastRequest!
        let body = JSONSerialization.object(with: String(data: lastRequest.body!, encoding: .utf8)!) as? NSDictionary
        XCTAssertEqual("PUT", lastRequest.method)
        XCTAssertEqual(expectedBody, body)
        
        let url = lastRequest.url
        XCTAssertEqual("https://device-api.urbanairship.com/api/channels/sdk/batch/some-channel?platform=ios", url?.absoluteString)
    }

    func testUpdateError() throws {
        let sessionError = AirshipErrors.error("error!")
        self.session.error = sessionError

        let expectation = XCTestExpectation(description: "callback called")

        let updates = [
            SubscriptionListUpdate(listId: "coffee", type: .unsubscribe),
            SubscriptionListUpdate(listId: "pizza", type: .subscribe)
        ]

        self.client.update(channelID: "some-channel", subscriptionListUpdates: updates, tagGroupUpdates: nil, attributeUpdates: nil) { response, error in
            XCTAssertEqual(sessionError as NSError, error! as NSError)
            XCTAssertNil(response)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }
   
}
