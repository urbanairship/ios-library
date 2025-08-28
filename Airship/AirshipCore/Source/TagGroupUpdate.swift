

/// NOTE: For internal use only. :nodoc:
enum TagGroupUpdateType: Int, Codable, Equatable, Hashable, Sendable {
    case add
    case remove
    case set
}

/// NOTE: For internal use only. :nodoc:
struct TagGroupUpdate: Codable, Sendable, Equatable, Hashable {
    let group: String
    let tags: [String]
    let type: TagGroupUpdateType
}


/// NOTE: For internal use only. :nodoc:
// Used by ChannelBulkAPIClient and DeferredAPIClient
struct TagGroupOverrides: Encodable, Sendable {
    var add: [String: [String]]? = nil
    var remove: [String: [String]]? = nil
    var set: [String: [String]]? = nil

    init(add: [String : [String]]? = nil, remove: [String : [String]]? = nil, set: [String : [String]]? = nil) {
        self.add = add
        self.remove = remove
        self.set = set
    }

    static func from(updates: [TagGroupUpdate]?) -> TagGroupOverrides? {
        guard let updates = updates, !updates.isEmpty else {
            return nil
        }
        var overrides = TagGroupOverrides()
        AudienceUtils.collapse(updates).forEach { tagUpdate in
            switch tagUpdate.type {
            case .set:
                if overrides.set == nil {
                    overrides.set = [:]
                }
                overrides.set?[tagUpdate.group] = tagUpdate.tags
            case .remove:
                if overrides.remove == nil {
                    overrides.remove = [:]
                }
                overrides.remove?[tagUpdate.group] = tagUpdate.tags
            case .add:
                if overrides.add == nil {
                    overrides.add = [:]
                }
                overrides.add?[tagUpdate.group] = tagUpdate.tags
            }
        }

        return overrides
    }
}


