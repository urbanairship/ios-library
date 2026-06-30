/* Copyright Airship and Contributors */

import Testing

@testable import AirshipCore

@Suite
struct TagGroupsEditorTest {

    @Test
    func testEditor() throws {
        var out: [TagGroupUpdate]?

        let editor = TagGroupsEditor { updates in
            out = updates
        }

        editor.add(["tag one"], group: "some group")
        editor.remove(["tag one"], group: "some group")
        editor.apply()

        #expect(2 == out?.count)
    }

    @Test
    func testInvalidTagGroup() throws {
        var out: [TagGroupUpdate]?

        let editor = TagGroupsEditor { updates in
            out = updates
        }

        editor.add(["tag one"], group: "")
        editor.set(["tag one"], group: "")
        editor.remove(["tag one"], group: "")
        editor.apply()

        #expect(out?.isEmpty ?? false)
    }

    @Test
    func testEmptyTags() throws {
        var out: [TagGroupUpdate]?

        let editor = TagGroupsEditor { updates in
            out = updates
        }

        editor.add([], group: "group one")
        editor.set([], group: "group two")
        editor.remove([], group: "group three")
        editor.apply()

        #expect(1 == out?.count)
        #expect(out?.first?.group == "group two")
        #expect(out?.first?.tags.isEmpty ?? false)
    }

    @Test
    func testNormalizeTags() throws {
        var out: [TagGroupUpdate]?

        let editor = TagGroupsEditor { updates in
            out = updates
        }

        editor.add(
            ["foo  ", "bar \n", "neat tag", "  cool"],
            group: "  group one  "
        )
        editor.apply()

        #expect(1 == out?.count)
        #expect(out?.first?.group == "group one")

        let tags = ["foo", "bar", "neat tag", "cool"]
        #expect(tags == out?.first?.tags)
    }

    @Test
    func testPreventDeviceTagGroup() throws {
        var out: [TagGroupUpdate]?

        let editor = TagGroupsEditor(allowDeviceTagGroup: false) { updates in
            out = updates
        }

        editor.add(["cool"], group: "ua_device")
        editor.apply()

        #expect(out?.isEmpty ?? false)
    }

    @Test
    func testAllowDeviceTagGroup() throws {
        var out: [TagGroupUpdate]?

        let editor = TagGroupsEditor(allowDeviceTagGroup: true) { updates in
            out = updates
        }

        editor.add(["cool"], group: "ua_device")
        editor.apply()

        #expect(1 == out?.count)
    }
}
