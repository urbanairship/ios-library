/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipMessageCenter

final class MessageCenterMessageTest: XCTestCase {
    func testHashing() throws {
        let date = Date()
        let m1 = MessageCenterMessage(title: "title",
                                      id: "identifier",
                                      contentType: .html,
                                      extra: ["cool": "story"],
                                      bodyURL: URL(string: "www.myspace.com")!,
                                      expirationDate: date,
                                      messageReporting: ["any" : "thing"],
                                      unread: true,
                                      sentDate: date,
                                      messageURL:  URL(string: "www.myspace.com")!,
                                      rawMessageObject: ["raw" : "message object"])

        let m2 = MessageCenterMessage(title: "title",
                                      id: "identifier",
                                      contentType: .html,
                                      extra: ["cool": "story"],
                                      bodyURL: URL(string: "www.myspace.com")!,
                                      expirationDate: date,
                                      messageReporting: ["any" : "thing"],
                                      unread: true,
                                      sentDate: date,
                                      messageURL:  URL(string: "www.myspace.com")!,
                                      rawMessageObject: ["raw" : "message object"])

        XCTAssertTrue(m1 == m2)

        var dictionary = [MessageCenterMessage: String]()
        dictionary[m1] = "keyed with m1"
        dictionary[m2] = "keyed with m2"
        XCTAssertEqual(dictionary.count, 1, "dictionary should only contain one entry since m1 and m2 are equal.")
    }
    
    func testContentTypeParsing() {
        // 1. Positive Cases: Map input string -> Expected Enum Case
        let validCases: [String: MessageCenterMessage.ContentType] = [
            "text/html": .html,
            "text/plain": .plain,
            "application/vnd.urbanairship.thomas+json;version=1": .native(version: 1),
            "application/vnd.urbanairship.thomas+json; version=2": .native(version: 2),
            "application/vnd.urbanairship.thomas+json; version=3; foo=bar": .native(version: 3),
        ]

        // 2. Negative Cases: List of strings that should return nil
        let invalidCases: [String] = [
            "",
            "text/json",
            "garbage_value",
            "application/vnd.urbanairship.thomas+json",
            "application/vnd.urbanairship.thomas+json;",
            "application/vnd.urbanairship.thomas+json;version=nan",
            "application/vnd.urbanairship.thomas+json;garbage version=1"
        ]

        // 3. Execution Loop
            
        // Check Positive Cases
        for (input, expected) in validCases {
            let result = MessageCenterMessage.ContentType.fromJson(value: input)
                
            XCTAssertEqual(
                result,
                expected,
                "Failed to parse valid input: '\(input)'"
            )
            
            if input == expected.jsonValue {
                XCTAssertEqual(
                    result?.jsonValue,
                    input,
                    "Round-trip jsonValue failed for '\(input)'"
                )
            }
        }

        // Check Negative Cases
        for input in invalidCases {
            XCTAssertNil(
                MessageCenterMessage.ContentType.fromJson(value: input),
                "Expected nil but got a value for invalid input: '\(input)'"
            )
        }
    }

    func testMessageProductIDNilWhenNotProvided() throws {
        let date = Date()
        let message = MessageCenterMessage(
            title: "title",
            id: "identifier",
            contentType: .native(version: 1),
            extra: [:],
            bodyURL: URL(string: "www.myspace.com")!,
            expirationDate: date,
            messageReporting: ["any" : "thing"],
            unread: true,
            sentDate: date,
            messageURL: URL(string: "www.myspace.com")!,
            rawMessageObject: ["raw" : "message object"]
        )

        XCTAssertNil(message.productID)
    }

    func testNativeMessageCenterUsesExplicitProductIDWhenProvided() throws {
        let date = Date()
        let message = MessageCenterMessage(
            title: "title",
            id: "identifier",
            contentType: .native(version: 1),
            extra: [:],
            bodyURL: URL(string: "www.myspace.com")!,
            expirationDate: date,
            messageReporting: ["any" : "thing"],
            unread: true,
            sentDate: date,
            messageURL: URL(string: "www.myspace.com")!,
            rawMessageObject: [
                "raw": "message object",
                "product_id": "custom_product_id"
            ]
        )

        XCTAssertEqual(message.productID, "custom_product_id")
    }
}
