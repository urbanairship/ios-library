/* Copyright Airship and Contributors */

import Testing

@testable import AirshipCore

@Suite struct TagEditorTest {

    @Test
    func testEditor() throws {
        var tags = ["cool", "story"]
        let editor = TagEditor { tagApplicator in
            tags = tagApplicator(tags)
        }

        editor.add(["dog", "cat"])
        editor.remove(["story"])
        editor.apply()

        #expect(tags == ["cool", "dog", "cat"])

        editor.set(["what", "cool"])
        editor.add(["nice"])
        editor.remove(["cool"])
        editor.apply()

        #expect(tags == ["what", "nice"])
    }
}
