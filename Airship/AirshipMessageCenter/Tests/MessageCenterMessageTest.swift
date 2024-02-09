/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipMessageCenter
final class MessageCenterMessageTest: XCTestCase {
    func testHashing() throws {
        let date = Date()
        let m1 = MessageCenterMessage(title: "title",
                                      id: "identifier",
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
                                      extra: ["cool": "story"],
                                      bodyURL: URL(string: "www.myspace.com")!,
                                      expirationDate: date,
                                      messageReporting: ["any" : "thing"],
                                      unread: true,
                                      sentDate: date,
                                      messageURL:  URL(string: "www.myspace.com")!,
                                      rawMessageObject: ["raw" : "message object"])

        XCTAssertTrue(m1.isEqual(m2))

        var dictionary = [MessageCenterMessage: String]()
        dictionary[m1] = "keyed with m1"
        dictionary[m2] = "keyed with m2"
        XCTAssertEqual(dictionary.count, 1, "dictionary should only contain one entry since m1 and m2 are equal.")
    }
}
