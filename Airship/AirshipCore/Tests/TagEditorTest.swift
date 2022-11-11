/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

class TagEditorTest: XCTestCase {

    func testEditor() throws {
        var tags = ["cool", "story"]
        let editor = TagEditor { tagApplicator in
            tags = tagApplicator(tags)
        }

        editor.add(["dog", "cat"])
        editor.remove(["story"])
        editor.apply()

        XCTAssertEqual(tags, ["cool", "dog", "cat"])

        editor.set(["what", "cool"])
        editor.add(["nice"])
        editor.remove(["cool"])
        editor.apply()

        XCTAssertEqual(tags, ["what", "nice"])
    }
}
