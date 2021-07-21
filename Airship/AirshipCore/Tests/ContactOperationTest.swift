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
        
        let operations = [update, resolve, identify, reset]

        let encoded = try JSONEncoder().encode(operations)
        let decoded = try JSONDecoder().decode([ContactOperation].self, from: encoded)
        
        
        XCTAssertEqual(4, decoded.count)
        XCTAssertEqual(.update, operations[0].type)
        XCTAssertEqual(.resolve, operations[1].type)
        XCTAssertEqual(.identify, operations[2].type)
        XCTAssertEqual(.reset, operations[3].type)
        
        XCTAssertNotNil(operations[0].payload)
        XCTAssertNotNil(operations[2].payload)
        
        XCTAssertEqual(encoded, try JSONEncoder().encode(decoded))
    }
}
