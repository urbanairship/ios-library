/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore
@testable import AirshipMessageCenter

final class MessageCenterAPIClientTest: XCTestCase {

    private var client: MessageCenterAPIClient! = nil
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

    override func setUpWithError() throws {
        self.client = MessageCenterAPIClient(
            config: .testConfig(),
            session: session
        )
    }

    /// Tests retrieving the message list with success.
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
        XCTAssertEqual(message.id, "some_mesg_id")
        XCTAssertEqual(message.title, "Message title")

        let request = self.session.lastRequest!
        XCTAssertEqual(
            "https://device-api.urbanairship.com/api/user/username/messages/",
            request.url!.absoluteString
        )
        XCTAssertEqual("GET", request.method)

        let expectedHeaders = [
            "X-UA-Channel-ID": "some channel",
            "If-Modified-Since": "some modified date",
            "Accept": "application/vnd.urbanairship+json; version=3;"
        ]

        XCTAssertEqual(expectedHeaders, request.headers)
    }

    /// Tests retrieving the message list with missing body failure
    func testRetrieveMessageMissingBody() async throws {
        self.session.response = HTTPURLResponse(
            url: URL(string: "www.anyurl.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [:]
        )

        do {
            let _ = try await self.client.retrieveMessageList(
                user: self.user,
                channelID: "some channel",
                lastModified: nil
            )
            XCTFail("Expected error")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    /// Tests retrieving the message list with status code failure
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

        XCTAssertEqual(response.statusCode, 500)
        XCTAssertNil(response.result)
    }

    /// Tests retrieving the message list with parsing failure
    func testRetrieveMessageJSONParseFailure() async throws {
        self.session.response = HTTPURLResponse(
            url: URL(string: "www.anyurl.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [:]
        )

        self.session.data = "{\"ok\":true}".data(using: .utf8)

        do {
            let _ = try await self.client.retrieveMessageList(
                user: self.user,
                channelID: "some channel",
                lastModified: nil
            )
            XCTFail("Expected error")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    /// Tests batch mark as read success.
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

        XCTAssertEqual(
            expected as NSDictionary,
            requestPayload as! NSDictionary
        )
    }

    /// Tests batch mark as read failure.
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
        XCTAssertEqual(500, response.statusCode)
    }

    /// Tests batch delete success.
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

        XCTAssertEqual(
            expected as NSDictionary,
            requestPayload as! NSDictionary
        )
    }

    /// Tests batch delete failure.
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
        XCTAssertEqual(500, response.statusCode)
    }

    /// Tests creating user with success.
    func testCreateUserSuccess() async throws {
        self.session.response = HTTPURLResponse(
            url: URL(string: "www.anyurl.com")!,
            statusCode: 201,
            httpVersion: nil,
            headerFields: [:]
        )

        self.session.data = try AirshipJSONUtils.data(
            [
                "user_id": "some user id",
                "password": "some password",
            ]
        )

        let response = try await self.client.createUser(
            withChannelID: "some channel"
        )
        let request = self.session.lastRequest!
        XCTAssertEqual(response.statusCode, 201)
        XCTAssertNotNil(response.result)
        XCTAssertEqual(response.result?.username, "some user id")
        XCTAssertEqual(response.result?.password, "some password")
        XCTAssertEqual(
            "https://device-api.urbanairship.com/api/user/",
            request.url?.absoluteString
        )
        XCTAssertEqual(
            AirshipRequestAuth.channelAuthToken(identifier: "some channel"),
            request.auth
        )
        XCTAssertEqual("POST", request.method)

        let requestPayload = try JSONSerialization.jsonObject(
            with: request.body!
        )

        let expected: [String: AnyHashable] = [
            "ios_channels": ["some channel"]
        ]

        XCTAssertEqual(
            expected as NSDictionary,
            requestPayload as! NSDictionary
        )
    }

    /// Tests creating user with status code failure
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
        XCTAssertEqual(response.statusCode, 400)
        XCTAssertNil(response.result)
    }

    /// Tests create user with parsing failure
    func testCreateUserFailureJSONParseError() async throws {
        self.session.response = HTTPURLResponse(
            url: URL(string: "www.anyurl.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [:]
        )

        self.session.data = try AirshipJSONUtils.data([:])
        do {
            let _ = try await self.client.createUser(withChannelID: "channelID")
            XCTFail("Expected error")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    /// Tests updating user with success.
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
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertNil(response.result)
        XCTAssertEqual(
            "https://device-api.urbanairship.com/api/user/username",
            request.url!.absoluteString
        )
        XCTAssertEqual("POST", request.method)

        let requestPayload = try JSONSerialization.jsonObject(
            with: request.body!
        )
        let expected: [String: AnyHashable] = [
            "ios_channels": [
                "add": ["some channel"]
            ]
        ]

        XCTAssertEqual(
            expected as NSDictionary,
            requestPayload as! NSDictionary
        )
    }

    /// Tests creating user with status code failure
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
            XCTAssertEqual(response.statusCode, 400)
            XCTAssertNil(response.result)
        }
    }

}
