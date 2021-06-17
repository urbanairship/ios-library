/* Copyright Airship and Contributors */

import Foundation

/**
 * Tag groups editor.
 */
@objc(UATagGroupsEdiitor)
public class TagGroupsEditor: NSObject {

    /**
     * Adds tags to the given group.
     * @param tags The tags.
     * @param group The group.
     */
    @objc(addTags:group:)
    public func add(_ tags: Array<String>, group: String) {

    }

    /**
     * Removes tags from the given group.
     * @param tags The tags.
     * @param group The group.
     */
    @objc(removeTags:group:)
    public func remove(_ tags: Array<String>, group: String) {

    }

    /**
     * Sets tags on the given group.
     * @param tags The tags.
     * @param group The group.
     */
    @objc(setTags:group:)
    public func set(_ tags: Array<String>, group: String) {

    }

    /**
     * Applys tag changes.
     */
    @objc
    public func apply() {

    }
}
