/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class ContactSubscriptionListAPIClientTest: XCTestCase {

    private let session: TestAirshipRequestSession = TestAirshipRequestSession()
    private var contactAPIClient: ContactSubscriptionListAPIClient!
    private var config: RuntimeConfig!

    override func setUpWithError() throws {
        var airshipConfig = AirshipConfig()
        airshipConfig.deviceAPIURL = "https://example.com"
        airshipConfig.requireInitialRemoteConfigEnabled = false
        self.config = RuntimeConfig(
            config: airshipConfig,
            dataStore: PreferenceDataStore(appKey: UUID().uuidString)
        )

        self.contactAPIClient = ContactSubscriptionListAPIClient(
            config: self.config,
            session: self.session
        )
    }


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
        XCTAssertTrue(response.isSuccess)

        XCTAssertEqual(expected, response.result!)

        XCTAssertEqual("GET", self.session.lastRequest?.method)
        XCTAssertEqual(
            "https://example.com/api/subscription_lists/contacts/some-contact",
            self.session.lastRequest?.url?.absoluteString
        )
    }

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
            XCTFail()
        }
        catch {

        }
    }

    func testGetContactListError() async throws {
        let sessionError = AirshipErrors.error("error!")
        self.session.error = sessionError

        do {
            _ = try await self.contactAPIClient.fetchSubscriptionLists(
                contactID: "some-contact"
            )
            XCTFail()
        }
        catch {

        }
    }

}
