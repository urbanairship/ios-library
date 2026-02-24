/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

class ChannelBulkUpdateAPIClientTest: XCTestCase {

    private var config: RuntimeConfig = .testConfig()
    private let session = TestAirshipRequestSession()
    var client: ChannelBulkUpdateAPIClient!

    override func setUpWithError() throws {
        self.client = ChannelBulkUpdateAPIClient(
            config: self.config,
            session: self.session
        )
    }

    func testUpdate() async throws {
        let date = Date()
        self.session.response = HTTPURLResponse(
            url: URL(string: "https://neat")!,
            statusCode: 200,
            httpVersion: "",
            headerFields: [String: String]()
        )


        let update = AudienceUpdate(
            subscriptionListUpdates: [
                SubscriptionListUpdate(
                    listId: "coffee",
                    type: .unsubscribe
                ),
                SubscriptionListUpdate(
                    listId: "pizza",
                    type: .subscribe
                ),
            ],
            tagGroupUpdates: [
                TagGroupUpdate(
                    group: "some-group",
                    tags: ["tag-1", "tag-2"],
                    type: .add
                ),
                TagGroupUpdate(
                    group: "some-other-group",
                    tags: ["tag-3", "tag-4"],
                    type: .set
                ),
            ],
            attributeUpdates: [
                AttributeUpdate(
                    attribute: "some-attribute",
                    type: .set,
                    jsonValue: "hello",
                    date: date
                )
            ]
        )

        let response = try await self.client.update(
            update,
            channelID: "some-channel"
        )

        XCTAssertEqual(response.statusCode, 200)

        let expectedBody =
            [
                "subscription_lists": [
                    [
                        "action": "unsubscribe",
                        "list_id": "coffee",
                    ],
                    [
                        "action": "subscribe",
                        "list_id": "pizza",
                    ],
                ],
                "tags": [
                    "add": [
                        "some-group": ["tag-1", "tag-2"]
                    ],
                    "set": [
                        "some-other-group": ["tag-3", "tag-4"]
                    ],
                ],
                "attributes": [
                    [
                        "action": "set",
                        "key": "some-attribute",
                        "timestamp": AirshipDateFormatter.string(fromDate: date, format: .isoDelimitter),
                        "value": "hello",
                    ]
                ],
            ] as NSDictionary

        let lastRequest = self.session.lastRequest!
        let body =
            AirshipJSONUtils.object(String(data: lastRequest.body!, encoding: .utf8)!)
            as? NSDictionary
        XCTAssertEqual("PUT", lastRequest.method)
        XCTAssertEqual(expectedBody, body)

        let url = lastRequest.url
        XCTAssertEqual(
            "https://device-api.urbanairship.com/api/channels/sdk/batch/some-channel?platform=ios",
            url?.absoluteString
        )
    }

    func testUpdateError() async throws {
        let sessionError = AirshipErrors.error("error!")
        self.session.error = sessionError


        let update = AudienceUpdate(
            subscriptionListUpdates: [
                SubscriptionListUpdate(
                    listId: "coffee",
                    type: .unsubscribe
                ),
                SubscriptionListUpdate(
                    listId: "pizza",
                    type: .subscribe
                ),
            ]
        )

        do {
            _ = try await self.client.update(
                update,
                channelID: "some-channel"
            )
        } catch {
            XCTAssertEqual(sessionError as NSError, error as NSError)

        }
    }

}
