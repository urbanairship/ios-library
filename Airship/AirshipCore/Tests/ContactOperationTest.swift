/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

class ContactOperationTests: XCTestCase {

    // SDK 16 payload
    private let legacyPayload = """
[{\"type\":\"update\",\"payload\":{\"tagUpdates\":[{\"group\":\"group\",\"tags\":[\"tags\"],\"type\":2}]}},{\"type\":\"resolve\",\"payload\":null},{\"type\":\"identify\",\"payload\":{\"identifier\":\"some-user\"}},{\"type\":\"reset\",\"payload\":null},{\"type\":\"registerEmail\",\"payload\":{\"address\":\"ua@airship.com\",\"options\":{\"doubleOptIn\":true,\"transactionalOptedIn\":700424522.44925797,\"properties\":{\"jsonEncodedValue\":\"{\\\"interests\\\":\\\"newsletter\\\"}\"}}}},{\"type\":\"registerSMS\",\"payload\":{\"options\":{\"senderID\":\"28855\"},\"msisdn\":\"15035556789\"}},{\"type\":\"registerOpen\",\"payload\":{\"address\":\"open_address\",\"options\":{\"identifiers\":{\"model\":\"4\"},\"platformName\":\"my_platform\"}}}]
"""

    // SDK 17 payload
    private let updatedPayload = """
[{\"type\":\"update\",\"payload\":{\"tagUpdates\":[{\"group\":\"group\",\"tags\":[\"tags\"],\"type\":2}]}},{\"type\":\"resolve\",\"payload\":null},{\"type\":\"identify\",\"payload\":{\"identifier\":\"some-user\"}},{\"type\":\"reset\",\"payload\":null},{\"type\":\"registerEmail\",\"payload\":{\"address\":\"ua@airship.com\",\"options\":{\"doubleOptIn\":true,\"transactionalOptedIn\":700424522.44925797,\"properties\":{\"interests\":\"newsletter\"}}}},{\"type\":\"registerSMS\",\"payload\":{\"options\":{\"senderID\":\"28855\"},\"msisdn\":\"15035556789\"}},{\"type\":\"registerOpen\",\"payload\":{\"address\":\"open_address\",\"options\":{\"identifiers\":{\"model\":\"4\"},\"platformName\":\"my_platform\"}}}]
"""

    func testLegacyDecode() throws {
        let fromJSON = try JSONDecoder().decode([ContactOperation].self, from: legacyPayload.data(using: .utf8)!)
        let toJSON = try JSONEncoder().encode(fromJSON)

        XCTAssertEqual(
            try AirshipJSON.from(json: String(data: toJSON, encoding: .utf8)),
            try AirshipJSON.from(json: legacyPayload)
        )
    }

    func testDecode() throws {
        let fromJSON = try JSONDecoder().decode([ContactOperation].self, from: updatedPayload.data(using: .utf8)!)
        let toJSON = try JSONEncoder().encode(fromJSON)

        XCTAssertEqual(
            try AirshipJSON.from(json: String(data: toJSON, encoding: .utf8)),
            try AirshipJSON.from(json: updatedPayload)
        )
    }

    func testEncode() throws {
        let expected = [
            ContactOperation.update(tagUpdates: [
                TagGroupUpdate.init(group: "group", tags: ["tags"], type: .set)
            ]),
            ContactOperation.resolve,
            ContactOperation.identify("some-user"),
            ContactOperation.reset,
            ContactOperation.registerEmail(
                address: "ua@airship.com",
                options: EmailRegistrationOptions.options(
                    transactionalOptedIn: Date(timeIntervalSinceReferenceDate: 700424522.44925797),
                    properties: ["interests": "newsletter"],
                    doubleOptIn: true
                )
            ),
            ContactOperation.registerSMS(
                msisdn: "15035556789",
                options: SMSRegistrationOptions.optIn(senderID: "28855")
            ),
            ContactOperation.registerOpen(
                address: "open_address",
                options: OpenRegistrationOptions.optIn(
                    platformName: "my_platform",
                    identifiers: ["model": "4"]
                )
            )
        ]

        let fromExpected = try JSONEncoder().encode(expected)

        XCTAssertEqual(
            try AirshipJSON.from(json: String(data: fromExpected, encoding: .utf8)),
            try AirshipJSON.from(json: updatedPayload)
        )
    }


}
