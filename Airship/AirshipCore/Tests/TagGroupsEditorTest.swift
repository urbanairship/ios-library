/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

class TagGroupsEditorTest: XCTestCase {
    
    func testEditor() throws {
        var out : [TagGroupUpdate]?
        
        let editor = TagGroupsEditor() { updates in
            out = updates
        }
        
        editor.add(["tag one"], group: "some group")
        editor.remove(["tag one"], group: "some group")
        editor.apply()
        
        XCTAssertEqual(2, out?.count)
    }
    
    func testInvalidTagGroup() throws {
        var out : [TagGroupUpdate]?
        
        let editor = TagGroupsEditor() { updates in
            out = updates
        }
        
        editor.add(["tag one"], group: "")
        editor.set(["tag one"], group: "")
        editor.remove(["tag one"], group: "")
        editor.apply()
        
        XCTAssertTrue(out?.isEmpty ?? false)
    }
    
    func testEmptyTags() throws {
        var out : [TagGroupUpdate]?
        
        let editor = TagGroupsEditor() { updates in
            out = updates
        }
        
        editor.add([], group: "group one")
        editor.set([], group: "group two")
        editor.remove([], group: "group three")
        editor.apply()
        
        XCTAssertEqual(1, out?.count)
        XCTAssertEqual(out?.first?.group, "group two")
        XCTAssertTrue(out?.first?.tags.isEmpty ?? false)
    }
    
    func testNormalizeTags() throws {
        var out : [TagGroupUpdate]?
        
        let editor = TagGroupsEditor() { updates in
            out = updates
        }
        
        editor.add(["foo  ", "bar \n", "neat tag", "  cool"], group: "  group one  ")
        editor.apply()
        
        XCTAssertEqual(1, out?.count)
        XCTAssertEqual(out?.first?.group, "group one")
        
        let tags = ["foo", "bar", "neat tag", "cool"]
        XCTAssertEqual(tags, out?.first?.tags)
    }

    func testPreventDeviceTagGroup() throws {
        var out : [TagGroupUpdate]?
        
        let editor = TagGroupsEditor(allowDeviceTagGroup: false) { updates in
            out = updates
        }
        
        editor.add(["cool"], group: "ua_device")
        editor.apply()
        
        XCTAssertTrue(out?.isEmpty ?? false)
    }
    
    func testAllowDeviceTagGroup() throws {
        var out : [TagGroupUpdate]?
        
        let editor = TagGroupsEditor(allowDeviceTagGroup: true) { updates in
            out = updates
        }
        
        editor.add(["cool"], group: "ua_device")
        editor.apply()
        
        XCTAssertEqual(1, out?.count)
    }
}
