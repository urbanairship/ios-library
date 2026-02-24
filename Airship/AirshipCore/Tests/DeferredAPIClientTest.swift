/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class DeferredAPIClientTest: AirshipBaseTest {
    var apiClient: DeferredAPIClient!
    private let testSession: TestAirshipRequestSession = TestAirshipRequestSession()
    private let exampleURL: URL = URL(string: "exampleurl://")!

    let date = AirshipDateFormatter.date(fromISOString: "2023-10-27T21:18:15")!

    override func setUpWithError() throws {
        self.apiClient = DeferredAPIClient(
            config: self.config,
            session: self.testSession
        )
    }

    func testResolve() async throws {
        self.testSession.response = HTTPURLResponse(
            url: exampleURL,
            statusCode: 200,
            httpVersion: "",
            headerFields: [:]
        )

        let responseBody = "some response".data(using: .utf8)
        self.testSession.data = responseBody

        let audienceOverrides = ChannelAudienceOverrides(
            tags: [
                TagGroupUpdate(
                    group: "some-group",
                    tags: ["tag-1", "tag-2"],
                    type: .add
                ),
                TagGroupUpdate(
                    group: "some-other-group",
                    tags: ["tag-3", "tag-4"],
                    type: .set
                )
            ],
            attributes: [
                AttributeUpdate(
                    attribute: "some-attribute",
                    type: .set,
                    jsonValue: "hello",
                    date: date
                )
            ]
        )

        let response = try await self.apiClient.resolve(
            url: exampleURL,
            channelID: "some channel id",
            contactID: "some contact id",
            stateOverrides: AirshipStateOverrides(
                appVersion: "1.0.0",
                sdkVersion: "2.0.0",
                notificationOptIn: true,
                localeLangauge: "en",
                localeCountry: "US"
            ),
            audienceOverrides: audienceOverrides,
            triggerContext: AirshipTriggerContext(
                type: "some trigger type",
                goal: 10.0,
                event: "event body"
            )
        )

        let expectedBody = """
        {
           "state_overrides":{
              "app_version":"1.0.0",
              "locale_language":"en",
              "sdk_version":"2.0.0",
              "locale_country":"US",
              "notification_opt_in":true
           },
           "tag_overrides":{
              "set":{
                 "some-other-group":[
                    "tag-3",
                    "tag-4"
                 ]
              },
              "add":{
                 "some-group":[
                    "tag-1",
                    "tag-2"
                 ]
              }
           },
           "channel_id":"some channel id",
           "platform":"ios",
           "trigger":{
              "event":"event body",
              "type":"some trigger type",
              "goal":10
           },
           "contact_id":"some contact id",
           "attribute_overrides":[
              {
                 "value":"hello",
                 "timestamp":"2023-10-27T21:18:15",
                 "key":"some-attribute",
                 "action":"set"
              }
           ]
        }
        """

        XCTAssertEqual(200, response.statusCode)
        XCTAssertEqual(responseBody, response.result)
        XCTAssertEqual("POST", self.testSession.lastRequest?.method)
        XCTAssertEqual(self.exampleURL, self.testSession.lastRequest?.url)
        XCTAssertEqual(["Accept": "application/vnd.urbanairship+json; version=3;"], self.testSession.lastRequest?.headers)
        XCTAssertEqual(AirshipRequestAuth.channelAuthToken(identifier: "some channel id"), self.testSession.lastRequest?.auth)
        XCTAssertEqual(
            try AirshipJSON.from(json: expectedBody),
            try AirshipJSON.from(data:self.testSession.lastRequest?.body)
        )
    }

    func testResolveMinimal() async throws {
        self.testSession.response = HTTPURLResponse(
            url: exampleURL,
            statusCode: 200,
            httpVersion: "",
            headerFields: [:]
        )
        self.testSession.data = "some response".data(using: .utf8)

        _ = try await self.apiClient.resolve(
            url: exampleURL,
            channelID: "some channel id",
            contactID: nil,
            stateOverrides: AirshipStateOverrides(
                appVersion: "1.0.0",
                sdkVersion: "2.0.0",
                notificationOptIn: true,
                localeLangauge: nil,
                localeCountry: nil
            ),
            audienceOverrides: ChannelAudienceOverrides(),
            triggerContext: nil
        )

        let expectedBody = """
        {
           "state_overrides":{
              "app_version":"1.0.0",
              "sdk_version":"2.0.0",
              "notification_opt_in":true
           },
           "channel_id":"some channel id",
           "platform":"ios"
        }
        """

        XCTAssertEqual(
            try AirshipJSON.from(json: expectedBody),
            try AirshipJSON.from(data:self.testSession.lastRequest?.body)
        )
    }
}
