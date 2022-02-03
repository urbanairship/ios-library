/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

class ContactOperationTests: XCTestCase {
    
    func testCoding() throws {
        let update = ContactOperation.update(tagUpdates: [TagGroupUpdate.init(group: "group", tags: ["tags"], type: .set)])
        let resolve = ContactOperation.resolve()
        let identify = ContactOperation.identify(identifier: "some-user")
        let reset = ContactOperation.reset()
        let registerEmail = ContactOperation.registerEmail("ua@airship.com", options: EmailRegistrationOptions.options(transactionalOptedIn: Date(), properties: ["interests" : "newsletter"], doubleOptIn: true))
        let registerSMS = ContactOperation.registerSMS("15035556789", options: SMSRegistrationOptions.optIn(senderID: "28855"))
        let registerOpen = ContactOperation.registerOpen("open_address", options: OpenRegistrationOptions.optIn(platformName: "my_platform", identifiers: ["model":"4"]))
        
        let operations = [update, resolve, identify, reset, registerEmail, registerSMS, registerOpen]

        let encoded = try JSONEncoder().encode(operations)
        let decoded = try JSONDecoder().decode([ContactOperation].self, from: encoded)
        
        
        XCTAssertEqual(7, decoded.count)
        XCTAssertEqual(.update, operations[0].type)
        XCTAssertEqual(.resolve, operations[1].type)
        XCTAssertEqual(.identify, operations[2].type)
        XCTAssertEqual(.reset, operations[3].type)
        XCTAssertEqual(.registerEmail, operations[4].type)
        XCTAssertEqual(.registerSMS, operations[5].type)
        XCTAssertEqual(.registerOpen, operations[6].type)
        
        
        XCTAssertNotNil(operations[0].payload)
        XCTAssertNotNil(operations[2].payload)
        XCTAssertNotNil(operations[4].payload)
        XCTAssertNotNil(operations[5].payload)
        XCTAssertNotNil(operations[6].payload)
        
        XCTAssertEqual(encoded, try JSONEncoder().encode(decoded))
    }
}
