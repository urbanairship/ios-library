/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

class AudienceUtilsTest: XCTestCase {
    
    func testCollapseTagGroupUpdates() throws {
        let updates = [
            TagGroupUpdate(group: "some-group", tags: ["1", "2", "3"], type: .remove),
            TagGroupUpdate(group: "some-group", tags: ["1", "2"], type: .add),
            TagGroupUpdate(group: "some-group", tags: ["4"], type: .set),
            TagGroupUpdate(group: "some-group", tags: ["5", "6"], type: .add),
            TagGroupUpdate(group: "some-group", tags: ["5"], type: .remove),
            TagGroupUpdate(group: "some-other-group", tags: ["10", "11"], type: .remove),
            TagGroupUpdate(group: "some-other-group", tags: ["12"], type: .add),
            TagGroupUpdate(group: "some-other-group", tags: ["10"], type: .add),
        ]
        
        let collapsed = AudienceUtils.collapse(updates)
        
        XCTAssertEqual(3, collapsed.count)
        XCTAssertEqual("some-group", collapsed[0].group)
        XCTAssertEqual(Set(["6", "4"]), Set(collapsed[0].tags))
        XCTAssertEqual(.set, collapsed[0].type)
        
        XCTAssertEqual("some-other-group", collapsed[1].group)
        XCTAssertEqual(Set(["12", "10"]), Set(collapsed[1].tags))
        XCTAssertEqual(.add, collapsed[1].type)
        
        XCTAssertEqual("some-other-group", collapsed[2].group)
        XCTAssertEqual(Set(["11"]), Set(collapsed[2].tags))
        XCTAssertEqual(.remove, collapsed[2].type)
    }
    
    func testCollapseTagGroupUpdatesEmptyTags() throws {
        let updates = [
            TagGroupUpdate(group: "set-group", tags: [], type: .set),
            TagGroupUpdate(group: "add-group", tags: [], type: .add),
            TagGroupUpdate(group: "remove-group", tags: [], type: .remove),

        ]
        
        let collapsed = AudienceUtils.collapse(updates)
        
        XCTAssertEqual(1, collapsed.count)
        XCTAssertEqual("set-group", collapsed[0].group)
        XCTAssertEqual(Set([]), Set(collapsed[0].tags))
        XCTAssertEqual(.set, collapsed[0].type)
    }

    func testCollapseAttributeUpdates() throws {
        let date = Date()
        let updates = [
            AttributeUpdate.remove(attribute: "some-attribute", date: date),
            AttributeUpdate.set(attribute: "some-attribute", value: "neat",  date: date),
            AttributeUpdate.set(attribute: "some-other-attribute", value: 12,  date: date),
            AttributeUpdate.remove(attribute: "some-other-attribute",  date: date)
        ]
        
        let collapsed = AudienceUtils.collapse(updates)
        
        XCTAssertEqual(2, collapsed.count)
        XCTAssertEqual("some-attribute", collapsed[0].attribute)
        XCTAssertEqual("neat", collapsed[0].jsonValue?.value() as! String)
        XCTAssertEqual(.set, collapsed[0].type)
        XCTAssertEqual(date, collapsed[0].date)


        XCTAssertEqual("some-other-attribute", collapsed[1].attribute)
        XCTAssertNil(collapsed[1].jsonValue?.value())
        XCTAssertEqual(.remove, collapsed[1].type)
        XCTAssertEqual(.set, collapsed[0].type)
    }
}
