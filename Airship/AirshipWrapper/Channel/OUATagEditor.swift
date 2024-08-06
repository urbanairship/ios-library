/* Copyright Airship and Contributors */

import Foundation
import AirshipCore


@objc
public class OUATagEditor: NSObject {
    
    var editor: TagEditor?
    
    /**
     * Adds tags.
     * - Parameters:
     *   - tags: The tags.
     */
    @objc(addTags:)
    public func add(_ tags: [String]) {
        self.editor?.add(tags)
    }
    
    /**
     * Adds a single tag.
     * - Parameters:
     *   - tag: The tag.
     */
    @objc(addTag:)
    public func add(_ tag: String) {
        self.editor?.add(tag)
    }
    
    /**
     * Removes tags from the given group.
     * - Parameters:
     *   - tags: The tags.
     */
    @objc(removeTags:)
    public func remove(_ tags: [String]) {
        self.editor?.remove(tags)
    }
    
    /**
     * Removes a single tag.
     * - Parameters:
     *   - tag: The tag.
     */
    @objc(removeTag:)
    public func remove(_ tag: String) {
        self.editor?.remove(tag)
    }
    
    /**
     * Sets tags on the given group.
     * - Parameters:
     *   - tags: The tags.
     */
    @objc(setTags:)
    public func set(_ tags: [String]) {
        self.editor?.set(tags)
    }
    
    /**
     * Clears tags.
     */
    @objc(clearTags)
    public func clear() {
        self.editor?.clear()
    }
    
    /**
     * Applies tag changes.
     */
    @objc
    public func apply() {
        self.editor?.apply()
    }
    
}
