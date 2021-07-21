/* Copyright Airship and Contributors */

import Foundation

// NOTE: For internal use only. :nodoc:
class AudienceUtils {
    
    class func collapse(_ updates: [TagGroupUpdate]) -> [TagGroupUpdate] {
        var adds: [String : Set<String>] = [:]
        var removes: [String : Set<String>] = [:]
        var sets: [String : Set<String>] = [:]
        
        updates.forEach { update in
            switch(update.type) {
            case .add:
                if (sets[update.group] != nil) {
                    update.tags.forEach { sets[update.group]?.insert($0) }
                } else {
                    removes[update.group]?.subtract(update.tags)
                    if (adds[update.group] == nil) {
                        adds[update.group] = Set<String>()
                    }
                    update.tags.forEach { adds[update.group]?.insert($0) }
                }
            case .remove:
                if (sets[update.group] != nil) {
                    sets[update.group]?.subtract(update.tags)
                } else {
                    adds[update.group]?.subtract(update.tags)
                    if (removes[update.group] == nil) {
                        removes[update.group] = Set<String>()
                    }
                    update.tags.forEach { removes[update.group]?.insert($0) }
                }
            case .set:
                removes[update.group] = nil
                adds[update.group] = nil
                sets[update.group] = Set(update.tags)
            }
        }
        
        let setUpdates = sets.map { TagGroupUpdate(group: $0.key, tags: Array($0.value), type: .set) }
        let addUpdates = adds.compactMap { $0.value.isEmpty ? nil : TagGroupUpdate(group: $0.key, tags: Array($0.value), type: .add) }
        let removeUpdates = removes.compactMap { $0.value.isEmpty ? nil : TagGroupUpdate(group: $0.key, tags: Array($0.value), type: .remove) }
        
        return setUpdates + addUpdates + removeUpdates
    }
    
    class func collapse(_ updates: [AttributeUpdate]) -> [AttributeUpdate] {
        var found : [String] = []
        let latest : [AttributeUpdate] = updates.reversed().compactMap { update in
            if (!found.contains(update.attribute)) {
                found.append(update.attribute)
                return update
            } else {
                return nil
            }
        }
        return latest.reversed()
    }
    
    class func applyTagUpdates(tagGroups: [String : [String]]?, tagGroupUpdates: [TagGroupUpdate]?) -> [String : [String]] {
        var updated = tagGroups ?? [:]
        
        tagGroupUpdates?.forEach { update in
            switch(update.type) {
            case .add:
                if (updated[update.group] == nil) {
                    updated[update.group] = []
                }
                updated[update.group]?.append(contentsOf: update.tags)
            case .remove:
                updated[update.group]?.removeAll(where: { update.tags.contains($0) })
            case .set:
                updated[update.group] = update.tags
            }
        }
        
        return updated.compactMapValues({ $0.isEmpty ? nil : $0})
    }
    
    class func applyAttributeUpdates(attributes: [String : JsonValue]?, attributeUpdates: [AttributeUpdate]?) -> [String : JsonValue] {
        var updated = attributes ?? [:]
        
        attributeUpdates?.forEach { update in
            switch(update.type) {
            case .set:
                updated[update.attribute] = update.jsonValue
            case .remove:
                updated[update.attribute] = nil
            }
        }
        
        return updated
    }
    
}
