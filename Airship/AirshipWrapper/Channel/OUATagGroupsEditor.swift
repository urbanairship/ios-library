/* Copyright Airship and Contributors */

import Foundation
import AirshipCore


@objc
public class OUATagGroupsEditor: NSObject {
    
    var editor: TagGroupsEditor?
    
    /**
     * Adds tags to the given group.
     * - Parameters:
     *   - tags: The tags.
     *   - group: The tag group.
     */
    @objc(addTags:group:)
    public func add(_ tags: [String], group: String) {
        self.editor?.add(tags, group: group)
    }

    /**
     * Removes tags from the given group.
     * - Parameters:
     *   - tags: The tags.
     *   - group: The tag group.
     */
    @objc(removeTags:group:)
    public func remove(_ tags: [String], group: String) {
        self.editor?.remove(tags, group: group)
    }

    /**
     * Sets tags on the given group.
     * - Parameters:
     *   - tags: The tags.
     *   - group: The tag group.
     */
    @objc(setTags:group:)
    public func set(_ tags: [String], group: String) {
        self.editor?.set(tags, group: group)
    }

    /**
     * Applies tag changes.
     */
    @objc
    public func apply() {
        self.editor?.apply()
    }
    
}
