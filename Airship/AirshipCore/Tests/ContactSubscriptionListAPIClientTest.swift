/* Copyright Airship and Contributors */

import Testing
@_spi(AirshipInternal) import AirshipBasement

@testable
import AirshipCore
import Foundation

@Suite struct ContactSubscriptionListAPIClientTest {

    private let session: TestAirshipRequestSession = TestAirshipRequestSession()
    private let contactAPIClient: ContactSubscriptionListAPIClient
    private let config: RuntimeConfig = RuntimeConfig.testConfig()

    init() {
        self.contactAPIClient = ContactSubscriptionListAPIClient(
            config: self.config,
            session: self.session
        )
    }

    @Test
    func testGetContactLists() async throws {
        let responseBody = """
            {
               "ok" : true,
               "subscription_lists": [
                  {
                     "list_ids": ["example_listId-1", "example_listId-3"],
                      "scope": "email"
                  },
                  {
                     "list_ids": ["example_listId-2", "example_listId-4"],
                     "scope": "app"
                  },
                  {
                     "list_ids": ["example_listId-2"],
                     "scope": "web"
                  }
               ],
            }
            """

        self.session.response = HTTPURLResponse(
            url: URL(string: "https://neat")!,
            statusCode: 200,
            httpVersion: "",
            headerFields: [String: String]()
        )
        self.session.data = responseBody.data(using: .utf8)

        let expected: [String: [ChannelScope]] = [
            "example_listId-1": [.email],
            "example_listId-2": [.app, .web],
            "example_listId-3": [.email],
            "example_listId-4": [.app],
        ]

        let response = try await self.contactAPIClient.fetchSubscriptionLists(
            contactID: "some-contact"
        )
        #expect(response.isSuccess)

        #expect(expected == response.result!)

        #expect("GET" == self.session.lastRequest?.method)
        #expect(
            "\(self.config.deviceAPIURL!)/api/subscription_lists/contacts/some-contact" ==
            self.session.lastRequest?.url?.absoluteString
        )
    }

    @Test
    func testGetContactListParseError() async throws {
        let responseBody = "What?"

        self.session.data = responseBody.data(using: .utf8)

        self.session.response = HTTPURLResponse(
            url: URL(string: "https://neat")!,
            statusCode: 200,
            httpVersion: "",
            headerFields: [String: String]()
        )

        do {
            _ = try await self.contactAPIClient.fetchSubscriptionLists(
                contactID: "some-contact"
            )
            Issue.record("Should throw")
        }
        catch {

        }
    }

    @Test
    func testGetContactListError() async throws {
        let sessionError = AirshipErrors.error("error!")
        self.session.error = sessionError

        do {
            _ = try await self.contactAPIClient.fetchSubscriptionLists(
                contactID: "some-contact"
            )
            Issue.record("Should throw")
        }
        catch {

        }
    }

}
