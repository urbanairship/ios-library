/* Copyright Airship and Contributors */

import Foundation

/**
 * Tag groups editor.
 */
@objc(UATagGroupsEditor)
public class TagGroupsEditor: NSObject {
    
    private var tagUpdates : [TagGroupUpdate] = []
    private var allowDeviceTagGroup = false
    private let completionHandler : ([TagGroupUpdate]) -> Void

    
    @objc
    public init(allowDeviceTagGroup : Bool, completionHandler: @escaping ([TagGroupUpdate]) -> Void) {
        self.allowDeviceTagGroup = allowDeviceTagGroup
        self.completionHandler = completionHandler
        super.init()
    }
    
    convenience init(completionHandler: @escaping ([TagGroupUpdate]) -> Void) {
        self.init(allowDeviceTagGroup: false, completionHandler: completionHandler)
    }
    
    /**
     * Adds tags to the given group.
     * - Parameters:
     *   - tags: The tags.
     *   - group: The tag group.
     */
    @objc(addTags:group:)
    public func add(_ tags: [String], group: String) {
        let group = AudienceUtils.normalizeTagGroup(group)
        let tags = AudienceUtils.normalizeTags(tags)
        
        guard isValid(group: group) else { return }
        guard !tags.isEmpty else { return }
        
        let update = TagGroupUpdate(group: group, tags: tags, type: .add)
        tagUpdates.append(update)
    }

    /**
     * Removes tags from the given group.
     * - Parameters:
     *   - tags: The tags.
     *   - group: The tag group.
     */
    @objc(removeTags:group:)
    public func remove(_ tags: [String], group: String) {
        let group = AudienceUtils.normalizeTagGroup(group)
        let tags = AudienceUtils.normalizeTags(tags)

        guard isValid(group: group) else { return }
        guard !tags.isEmpty else { return }
        
        let update = TagGroupUpdate(group: group, tags: tags, type: .remove)
        tagUpdates.append(update)
    }

    /**
     * Sets tags on the given group.
     * - Parameters:
     *   - tags: The tags.
     *   - group: The tag group.
     */
    @objc(setTags:group:)
    public func set(_ tags: [String], group: String) {
        let group = AudienceUtils.normalizeTagGroup(group)
        let tags = AudienceUtils.normalizeTags(tags)

        guard isValid(group: group) else { return }
        
        let update = TagGroupUpdate(group: group, tags: tags, type: .set)
        tagUpdates.append(update)
    }

    /**
     * Applies tag changes.
     */
    @objc
    public func apply() {
        self.completionHandler(tagUpdates)
        tagUpdates.removeAll()
    }
    
    private func isValid(group: String) -> Bool {
        guard !group.isEmpty else {
            AirshipLogger.error("Invalid tag group \(group)")
            return false
        }
        
        if (group == "ua_device" && !allowDeviceTagGroup) {
            AirshipLogger.error("Unable to modify device tag group")
            return false
        }
        
        return true
    }
}
