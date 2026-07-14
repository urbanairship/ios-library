/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable import AirshipCore
@_spi(AirshipInternal) @testable import AirshipMessageCenter

struct MessageCenterAPIClientTest {

    private let client: MessageCenterAPIClient
    private let session = TestAirshipRequestSession()
    private let user = MessageCenterUser(
        username: "username",
        password: "password"
    )
    private let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let messages = [
        MessageCenterMessage(
            title: "Foo message",
            id: "foo",
            contentType: .html,
            extra: [:],
            bodyURL: URL(string: "anyurl.com")!,
            expirationDate: nil,
            messageReporting: ["foo": "reporting"],
            unread: true,
            sentDate: Date(),
            messageURL: URL(string: "anyurl.com")!,
            rawMessageObject: [:]
        )
    ]

    init() {
        self.client = MessageCenterAPIClient(
            config: .testConfig(),
            session: session
        )
    }

    /// Tests retrieving the message list with success.
    @Test
    func testRetrieveMessageListSuccess() async throws {
        self.session.response = HTTPURLResponse(
            url: URL(string: "www.anyurl.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [:]
        )

        let messageResponse: String = """
            {
                "messages": [
                    {
                        "message_id": "some_mesg_id",
                        "message_url": "https://go.urbanairship.com/api/user/userId/messages/message/some_mesg_id/",
                        "message_body_url": "https://go.urbanairship.com/api/user/userId/messages/message/some_mesg_id/body/",
                        "message_read_url": "https://go.urbanairship.com/api/user/userId/messages/message/some_mesg_id/read/",
                        "unread": true,
                        "message_sent": "2010-09-05 12:13 -0000",
                        "title": "Message title",
                        "extra": {
                            "some_key": "some_value"
                        },
                        "message_reporting": { "cool": "story" },
                        "content_type": "text/html",
                        "content_size": "128"
                    }
                ]
            }
            """

        self.session.data = messageResponse.data(using: .utf8)

        let response = try await self.client.retrieveMessageList(
            user: self.user,
            channelID: "some channel",
            lastModified: "some modified date"
        )

        let messages = response.result!
        let message = messages[0] as MessageCenterMessage
        #expect(message.id == "some_mesg_id")
        #expect(message.title == "Message title")
        #expect(message.contentType == .html)

        let request = self.session.lastRequest!
        #expect(
            "https://device-api.urbanairship.com/api/user/username/messages/" ==
            request.url!.absoluteString
        )
        #expect("GET" == request.method)

        let expectedHeaders = [
            "X-UA-Channel-ID": "some channel",
            "If-Modified-Since": "some modified date",
            "Accept": "application/vnd.urbanairship+json; version=3;"
        ]

        #expect(expectedHeaders == request.headers)
    }

    /// Tests retrieving the message list with missing body failure
    @Test
    func testRetrieveMessageMissingBody() async throws {
        self.session.response = HTTPURLResponse(
            url: URL(string: "www.anyurl.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [:]
        )

        await #expect(throws: (any Error).self) {
            _ = try await self.client.retrieveMessageList(
                user: self.user,
                channelID: "some channel",
                lastModified: nil
            )
        }
    }

    /// Tests retrieving the message list with status code failure
    @Test
    func testRetrieveMessageFailure() async throws {
        self.session.response = HTTPURLResponse(
            url: URL(string: "www.anyurl.com")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: [:]
        )

        self.session.data = "{\"ok\":true}".data(using: .utf8)

        let response = try await self.client.retrieveMessageList(
            user: self.user,
            channelID: "some channel",
            lastModified: nil
        )

        #expect(response.statusCode == 500)
        #expect(response.result == nil)
    }

    /// Tests retrieving the message list with parsing failure
    @Test
    func testRetrieveMessageJSONParseFailure() async throws {
        self.session.response = HTTPURLResponse(
            url: URL(string: "www.anyurl.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [:]
        )

        self.session.data = "{\"ok\":true}".data(using: .utf8)

        await #expect(throws: (any Error).self) {
            _ = try await self.client.retrieveMessageList(
                user: self.user,
                channelID: "some channel",
                lastModified: nil
            )
        }
    }

    /// Tests batch mark as read success.
    @Test
    func testBatchMarkAsReadSuccess() async throws {
        self.session.response = HTTPURLResponse(
            url: URL(string: "www.anyurl.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [:]
        )

        self.session.data = "{\"ok\":true}".data(using: .utf8)
        let _ = try await self.client.performBatchMarkAsRead(
            forMessages: self.messages,
            user: self.user,
            channelID: "some channel"
        )

        let request = self.session.lastRequest!
        let requestPayload = try JSONSerialization.jsonObject(
            with: request.body!
        )

        let expected: [String: AnyHashable] = [
            "messages": [["foo": "reporting"]]
        ]

        #expect(
            expected as NSDictionary ==
            requestPayload as! NSDictionary
        )
    }

    /// Tests batch mark as read failure.
    @Test
    func testBatchMarkAsReadFailure() async throws {
        self.session.response = HTTPURLResponse(
            url: URL(string: "www.anyurl.com")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: [:]
        )

        self.session.data = "{\"ok\":true}".data(using: .utf8)
        let response = try await self.client.performBatchMarkAsRead(
            forMessages: self.messages,
            user: self.user,
            channelID: "some channel"
        )
        #expect(500 == response.statusCode)
    }

    /// Tests batch delete success.
    @Test
    func testBatchDeleteSuccess() async throws {
        self.session.response = HTTPURLResponse(
            url: URL(string: "www.anyurl.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [:]
        )

        self.session.data = "{\"ok\":true}".data(using: .utf8)
        let _ = try await self.client.performBatchDelete(
            forMessages: self.messages,
            user: self.user,
            channelID: "some channel"
        )

        let request = self.session.lastRequest!
        let requestPayload = try JSONSerialization.jsonObject(
            with: request.body!
        )

        let expected: [String: AnyHashable] = [
            "messages": [["foo": "reporting"]]
        ]

        #expect(
            expected as NSDictionary ==
            requestPayload as! NSDictionary
        )
    }

    /// Tests batch delete failure.
    @Test
    func testBatchDeleteAsReadFailure() async throws {
        self.session.response = HTTPURLResponse(
            url: URL(string: "www.anyurl.com")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: [:]
        )

        self.session.data = "{\"ok\":true}".data(using: .utf8)
        let response = try await self.client.performBatchDelete(
            forMessages: self.messages,
            user: self.user,
            channelID: "some channel"
        )
        #expect(500 == response.statusCode)
    }

    /// Tests creating user with success.
    @Test
    func testCreateUserSuccess() async throws {
        self.session.response = HTTPURLResponse(
            url: URL(string: "www.anyurl.com")!,
            statusCode: 201,
            httpVersion: nil,
            headerFields: [:]
        )

        self.session.data = (try? AirshipJSON.wrap(
            [
                "user_id": "some user id",
                "password": "some password",
            ]
        ).toData()) ?? Data()

        let response = try await self.client.createUser(
            withChannelID: "some channel"
        )
        let request = self.session.lastRequest!
        #expect(response.statusCode == 201)
        #expect(response.result != nil)
        #expect(response.result?.username == "some user id")
        #expect(response.result?.password == "some password")
        #expect(
            "https://device-api.urbanairship.com/api/user/" ==
            request.url?.absoluteString
        )
        #expect(
            AirshipRequestAuth.channelAuthToken(identifier: "some channel") ==
            request.auth
        )
        #expect("POST" == request.method)

        let requestPayload = try JSONSerialization.jsonObject(
            with: request.body!
        )

        let expected: [String: AnyHashable] = [
            "ios_channels": ["some channel"]
        ]

        #expect(
            expected as NSDictionary ==
            requestPayload as! NSDictionary
        )
    }

    /// Tests creating user with status code failure
    @Test
    func testCreateUserFailure() async throws {
        self.session.response = HTTPURLResponse(
            url: URL(string: "www.anyurl.com")!,
            statusCode: 400,
            httpVersion: nil,
            headerFields: [:]
        )
        self.session.data = "{\"ok\":true}".data(using: .utf8)
        let response = try await self.client.createUser(
            withChannelID: "channelID"
        )
        #expect(response.statusCode == 400)
        #expect(response.result == nil)
    }

    /// Tests create user with parsing failure
    @Test
    func testCreateUserFailureJSONParseError() async throws {
        self.session.response = HTTPURLResponse(
            url: URL(string: "www.anyurl.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [:]
        )

        self.session.data = (try? AirshipJSON.wrap([:]).toData()) ?? Data()
        await #expect(throws: (any Error).self) {
            _ = try await self.client.createUser(withChannelID: "channelID")
        }
    }

    /// Tests updating user with success.
    @Test
    func testUpdateUserSuccess() async throws {
        self.session.response = HTTPURLResponse(
            url: URL(string: "www.anyurl.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [:]
        )

        let response = try await self.client.updateUser(
            self.user,
            channelID: "some channel"
        )

        let request = self.session.lastRequest!
        #expect(response.statusCode == 200)
        #expect(response.result == nil)
        #expect(
            "https://device-api.urbanairship.com/api/user/username" ==
            request.url!.absoluteString
        )
        #expect("POST" == request.method)

        let requestPayload = try JSONSerialization.jsonObject(
            with: request.body!
        )
        let expected: [String: AnyHashable] = [
            "ios_channels": [
                "add": ["some channel"]
            ]
        ]

        #expect(
            expected as NSDictionary ==
            requestPayload as! NSDictionary
        )
    }

    @Test
    func testRetrieveMessageListInvalidContentTypeBecomesUnknown() async throws {
        self.session.response = HTTPURLResponse(
            url: URL(string: "www.anyurl.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [:]
        )

        let messageResponse: String = """
            {
                "messages": [
                    {
                        "message_id": "some_mesg_id",
                        "message_url": "https://go.urbanairship.com/api/user/userId/messages/message/some_mesg_id/",
                        "message_body_url": "https://go.urbanairship.com/api/user/userId/messages/message/some_mesg_id/body/",
                        "message_read_url": "https://go.urbanairship.com/api/user/userId/messages/message/some_mesg_id/read/",
                        "unread": true,
                        "message_sent": "2010-09-05 12:13 -0000",
                        "title": "Message title",
                        "extra": {
                            "some_key": "some_value"
                        },
                        "message_reporting": { "cool": "story" },
                        "content_type": "application/x-unknown",
                        "content_size": "128"
                    }
                ]
            }
            """

        self.session.data = messageResponse.data(using: .utf8)

        let response = try await self.client.retrieveMessageList(
            user: self.user,
            channelID: "some channel",
            lastModified: nil
        )

        let messages = response.result!
        #expect(messages.count == 1)
        #expect(messages[0].contentType == .unknown("application/x-unknown"))
    }

    @Test
    func testRetrieveMessageListMissingContentTypeBecomesUnknown() async throws {
        self.session.response = HTTPURLResponse(
            url: URL(string: "www.anyurl.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [:]
        )

        let messageResponse: String = """
            {
                "messages": [
                    {
                        "message_id": "some_mesg_id",
                        "message_url": "https://go.urbanairship.com/api/user/userId/messages/message/some_mesg_id/",
                        "message_body_url": "https://go.urbanairship.com/api/user/userId/messages/message/some_mesg_id/body/",
                        "message_read_url": "https://go.urbanairship.com/api/user/userId/messages/message/some_mesg_id/read/",
                        "unread": true,
                        "message_sent": "2010-09-05 12:13 -0000",
                        "title": "Message title",
                        "extra": {
                            "some_key": "some_value"
                        },
                        "message_reporting": { "cool": "story" },
                        "content_size": "128"
                    }
                ]
            }
            """

        self.session.data = messageResponse.data(using: .utf8)

        let response = try await self.client.retrieveMessageList(
            user: self.user,
            channelID: "some channel",
            lastModified: nil
        )

        let messages = response.result!
        #expect(messages.count == 1)
        #expect(messages[0].contentType == .unknown(nil))
    }

    /// Tests creating user with status code failure
    @Test
    func testUpdateUserFailure() async throws {
        self.session.response = HTTPURLResponse(
            url: URL(string: "www.anyurl.com")!,
            statusCode: 400,
            httpVersion: nil,
            headerFields: [:]
        )
        do {
            let response = try await self.client.updateUser(
                self.user,
                channelID: "some channel"
            )
            #expect(response.statusCode == 400)
            #expect(response.result == nil)
        }
    }

}
