/* Copyright Airship and Contributors */

import Testing
import Foundation

@_spi(AirshipInternal) import AirshipBasement
@testable import AirshipCore

@Suite struct ContactChannelsAPIClientTest {

    private let session: TestAirshipRequestSession = TestAirshipRequestSession()
    private let client: ContactChannelsAPIClient

    init() {
        self.session.response = HTTPURLResponse(
            url: URL(string: "https://contacts_test")!,
            statusCode: 200,
            httpVersion: "",
            headerFields: [String: String]()
        )

        self.client = ContactChannelsAPIClient(
            config: RuntimeConfig.testConfig(),
            session: self.session
        )
    }

    @Test
    func testEmailTrackingDates() async throws {
        self.session.data = """
            {
              "channels": [
                {
                  "type": "email",
                  "channel_id": "some-channel",
                  "email_address": "u*******@airship.com",
                  "commercial_opted_in": "2022-12-01T00:00:00",
                  "open_tracking_opted_in": "2022-12-11T00:00:00",
                  "open_tracking_opted_out": "2022-12-12T00:00:00",
                  "click_tracking_opted_out": "2022-12-13T00:00:00"
                }
              ]
            }
            """
            .data(using: .utf8)

        let response = try await client.fetchAssociatedChannelsList(contactID: "some-contact")

        let expected: ContactChannel = .email(
            .registered(
                ContactChannel.Email.Registered(
                    channelID: "some-channel",
                    maskedAddress: "u*******@airship.com",
                    commercialOptedIn: AirshipDateFormatter.date(from: "2022-12-01T00:00:00"),
                    openTrackingOptedIn: AirshipDateFormatter.date(from: "2022-12-11T00:00:00"),
                    openTrackingOptedOut: AirshipDateFormatter.date(from: "2022-12-12T00:00:00"),
                    clickTrackingOptedOut: AirshipDateFormatter.date(from: "2022-12-13T00:00:00")
                )
            )
        )
        #expect(response.result == [expected])
    }
}
