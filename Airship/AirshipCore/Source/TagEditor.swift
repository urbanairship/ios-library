/* Copyright Airship and Contributors */

import Foundation

/**
 * Tag editor.
 */
@objc(UATagEditor)
public class TagEditor: NSObject {
    
    typealias TagApplicator = ([String]) -> [String]

    private var tagOperations: [([String]) -> [String]] = []
    private let onApply: (TagApplicator) -> Void

    init(onApply: @escaping (TagApplicator) -> Void) {
        self.onApply = onApply
        super.init()
    }
    
    /**
     * Adds tags.
     * - Parameters:
     *   - tags: The tags.
     */
    @objc(addTags:)
    public func add(_ tags: [String]) {
        let normalizedTags = AudienceUtils.normalizeTags(tags)
        self.tagOperations.append({ incoming in
            var mutable = incoming
            mutable.append(contentsOf: normalizedTags)
            return mutable
        })
    }

    /**
     * Adds a single tag.
     * - Parameters:
     *   - tag: The tatg.
     */
    @objc(addTag:)
    public func add(_ tag: String) {
        self.add([tag])
    }
    
    /**
     * Removes tags from the given group.
     * - Parameters:
     *   - tags: The tags.
     */
    @objc(removeTags:)
    public func remove(_ tags: [String]) {
        let normalizedTags = AudienceUtils.normalizeTags(tags)
        self.tagOperations.append({ incoming in
            var mutable = incoming
            mutable.removeAll(where: { normalizedTags.contains($0) })
            return mutable
        })
    }
    
    /**
     * Removes a single tag.
     * - Parameters:
     *   - tag: The tatg.
     */
    @objc(removeTag:)
    public func remove(_ tag: String) {
        self.remove([tag])
    }

    /**
     * Sets tags on the given group.
     * - Parameters:
     *   - tags: The tags.
     */
    @objc(setTags:)
    public func set(_ tags: [String]) {
        let normalizedTags = AudienceUtils.normalizeTags(tags)
        self.tagOperations.append({ incoming in
            return normalizedTags
        })
    }
    
    /**
     * Clears tags.
     */
    @objc(clearTags)
    public func clear() {
        self.tagOperations.append({ _ in
            return []
        })
    }

    /**
     * Applies tag changes.
     */
    @objc
    public func apply() {
        let operations = tagOperations
        tagOperations.removeAll()
        self.onApply({ tags in
            return operations.reduce(tags) { result, operation  in
                return operation(result)
            }
        })
    }
}

