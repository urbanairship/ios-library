/* Copyright Airship and Contributors */

import Testing
import Foundation
import AirshipCore
@testable import AirshipMessageCenter

struct MessageCenterMessageTest {
    @Test
    func testHashing() throws {
        let date = Date()
        let m1 = MessageCenterMessage(title: "title",
                                      id: "identifier",
                                      contentType: .html,
                                      extra: ["cool": "story"],
                                      bodyURL: URL(string: "www.myspace.com")!,
                                      expirationDate: date,
                                      messageReporting: ["any": "thing"],
                                      unread: true,
                                      sentDate: date,
                                      messageURL:  URL(string: "www.myspace.com")!,
                                      rawMessageObject: ["raw": "message object"])

        let m2 = MessageCenterMessage(title: "title",
                                      id: "identifier",
                                      contentType: .html,
                                      extra: ["cool": "story"],
                                      bodyURL: URL(string: "www.myspace.com")!,
                                      expirationDate: date,
                                      messageReporting: ["any": "thing"],
                                      unread: true,
                                      sentDate: date,
                                      messageURL:  URL(string: "www.myspace.com")!,
                                      rawMessageObject: ["raw": "message object"])

        #expect(m1 == m2)

        var dictionary = [MessageCenterMessage: String]()
        dictionary[m1] = "keyed with m1"
        dictionary[m2] = "keyed with m2"
        #expect(dictionary.count == 1, "dictionary should only contain one entry since m1 and m2 are equal.")
    }
    
    @Test
    func testEqualityConsidersUnreadState() {
        let date = Date()
        let unread = MessageCenterMessage(
            title: "title",
            id: "identifier",
            contentType: .html,
            extra: [:],
            bodyURL: URL(string: "www.myspace.com")!,
            expirationDate: date,
            messageReporting: nil,
            unread: true,
            sentDate: date,
            messageURL: URL(string: "www.myspace.com")!,
            rawMessageObject: ["raw": "message object"]
        )

        let read = MessageCenterMessage(
            title: "title",
            id: "identifier",
            contentType: .html,
            extra: [:],
            bodyURL: URL(string: "www.myspace.com")!,
            expirationDate: date,
            messageReporting: nil,
            unread: false,
            sentDate: date,
            messageURL: URL(string: "www.myspace.com")!,
            rawMessageObject: ["raw": "message object"]
        )

        #expect(unread != read)
        #expect(unread.hashValue != read.hashValue)

        var readCopy = unread
        readCopy.unread = false
        #expect(read == readCopy)
        #expect(read.hashValue == readCopy.hashValue)
    }

    @Test
    func testContentTypeDecoding() throws {
        let validCases: [String: MessageCenterMessage.ContentType] = [
            "text/html": .html,
            "text/plain": .plain,
            "application/vnd.urbanairship.thomas+json;version=1": .native(version: 1),
            "application/vnd.urbanairship.thomas+json; version=2": .native(version: 2),
            "application/vnd.urbanairship.thomas+json; version=3; foo=bar": .native(version: 3),
        ]

        let unknownCases: [String] = [
            "",
            "text/json",
            "garbage_value",
            "application/vnd.urbanairship.thomas+json",
            "application/vnd.urbanairship.thomas+json;",
            "application/vnd.urbanairship.thomas+json;version=nan",
            "application/vnd.urbanairship.thomas+json;garbage version=1"
        ]

        for (input, expected) in validCases {
            let data = try JSONEncoder().encode(input)
            let result = try JSONDecoder().decode(MessageCenterMessage.ContentType.self, from: data)

            #expect(
                result == expected,
                "Failed to decode valid input: '\(input)'"
            )

            let roundTripped = try JSONDecoder().decode(
                MessageCenterMessage.ContentType.self,
                from: JSONEncoder().encode(result)
            )
            #expect(
                roundTripped == expected,
                "Round-trip Codable failed for '\(input)'"
            )
        }

        for input in unknownCases {
            let data = try JSONEncoder().encode(input)
            let result = try JSONDecoder().decode(MessageCenterMessage.ContentType.self, from: data)
            #expect(
                result == .unknown(input),
                "Expected .unknown for unrecognized input: '\(input)'"
            )
        }
    }

    @Test
    func testMessageProductIDNilWhenNotProvided() throws {
        let date = Date()
        let message = MessageCenterMessage(
            title: "title",
            id: "identifier",
            contentType: .native(version: 1),
            extra: [:],
            bodyURL: URL(string: "www.myspace.com")!,
            expirationDate: date,
            messageReporting: ["any": "thing"],
            unread: true,
            sentDate: date,
            messageURL: URL(string: "www.myspace.com")!,
            rawMessageObject: ["raw": "message object"]
        )

        #expect(message.productID == nil)
    }

    @Test
    func testNativeMessageCenterUsesExplicitProductIDWhenProvided() throws {
        let date = Date()
        let message = MessageCenterMessage(
            title: "title",
            id: "identifier",
            contentType: .native(version: 1),
            extra: [:],
            bodyURL: URL(string: "www.myspace.com")!,
            expirationDate: date,
            messageReporting: ["any": "thing"],
            unread: true,
            sentDate: date,
            messageURL: URL(string: "www.myspace.com")!,
            rawMessageObject: [
                "raw": "message object",
                "product_id": "custom_product_id"
            ]
        )

        #expect(message.productID == "custom_product_id")
    }
}
