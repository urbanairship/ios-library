/* Copyright Airship and Contributors */



/// Tag editor.
public class TagEditor {

    typealias TagApplicator = ([String]) -> [String]

    private var tagOperations: [([String]) -> [String]] = []
    private let onApply: (TagApplicator) -> Void

    init(onApply: @escaping (TagApplicator) -> Void) {
        self.onApply = onApply
    }

    /**
     * Adds tags.
     * - Parameters:
     *   - tags: The tags.
     */
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
     *   - tag: The tag.
     */
    public func add(_ tag: String) {
        self.add([tag])
    }

    /**
     * Removes tags from the given group.
     * - Parameters:
     *   - tags: The tags.
     */
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
     *   - tag: The tag.
     */
    public func remove(_ tag: String) {
        self.remove([tag])
    }

    /**
     * Sets tags on the given group.
     * - Parameters:
     *   - tags: The tags.
     */
    public func set(_ tags: [String]) {
        let normalizedTags = AudienceUtils.normalizeTags(tags)
        self.tagOperations.append({ incoming in
            return normalizedTags
        })
    }

    /**
     * Clears tags.
     */
    public func clear() {
        self.tagOperations.append({ _ in
            return []
        })
    }

    /**
     * Applies tag changes.
     */
    public func apply() {
        let operations = tagOperations
        tagOperations.removeAll()
        self.onApply({ tags in
            return operations.reduce(tags) { result, operation in
                return operation(result)
            }
        })
    }
}
