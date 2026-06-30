/* Copyright Airship and Contributors */

import Testing

@_spi(AirshipInternal) import AirshipBasement
@testable import AirshipCore
import Foundation

@Suite struct ChannelBulkUpdateAPIClientTest {

    private let config: RuntimeConfig = .testConfig()
    private let session = TestAirshipRequestSession()
    let client: ChannelBulkUpdateAPIClient

    init() throws {
        self.client = ChannelBulkUpdateAPIClient(
            config: self.config,
            session: self.session
        )
    }

    @Test
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

        #expect(response.statusCode == 200)

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
                        "timestamp": AirshipDateFormatter.string(fromDate: date, format: .iso8601WithMilliseconds),
                        "value": "hello",
                    ]
                ],
            ] as NSDictionary

        let lastRequest = self.session.lastRequest!
        let bodyJSON = try AirshipJSON.from(data: lastRequest.body)
        let expectedJSON = try AirshipJSON.wrap(expectedBody as! [String: Any])
          
        #expect("PUT" == lastRequest.method)
        #expect(expectedJSON == bodyJSON)

        let url = lastRequest.url
        #expect(
            "https://device-api.urbanairship.com/api/channels/sdk/batch/some-channel?platform=ios" ==
            url?.absoluteString
        )
    }

    @Test
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
            #expect(sessionError as NSError == error as NSError)

        }
    }

}
