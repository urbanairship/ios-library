/* Copyright Airship and Contributors */

import Foundation

// NOTE: For internal use only. :nodoc:
@objc(UAAudienceUtils)
public class AudienceUtils : NSObject {
    
    class func collapse(_ updates: [SubscriptionListUpdate]) -> [SubscriptionListUpdate] {
        var subscribes: [String]  = []
        var unsubscribes: [String] = []
        
        updates.forEach { update in
            switch(update.type) {
            case .subscribe:
                subscribes.append(update.listId)
                unsubscribes.removeAll(where: { $0 == update.listId })
            case .unsubscribe:
                unsubscribes.append(update.listId)
                subscribes.removeAll(where: { $0 == update.listId })
            }
        }
        
        let subscribeUpdates = subscribes.map { SubscriptionListUpdate(listId: $0, type: .subscribe) }
        
        let unsubscribeUpdates = unsubscribes.map { SubscriptionListUpdate(listId: $0, type: .unsubscribe) }
        
        return subscribeUpdates + unsubscribeUpdates
    }
    
    @objc(collapseTagGroupUpdates:)
    public class func collapse(_ updates: [TagGroupUpdate]) -> [TagGroupUpdate] {
        var adds: [String : [String]] = [:]
        var removes: [String : [String]] = [:]
        var sets: [String : [String]] = [:]
        
        updates.forEach { update in
            switch(update.type) {
            case .add:
                if (sets[update.group] != nil) {
                    update.tags.forEach { sets[update.group]?.append($0) }
                } else {
                    removes[update.group]?.removeAll(where: { update.tags.contains($0) })
                    if (adds[update.group] == nil) {
                        adds[update.group] = []
                    }
                    update.tags.forEach { adds[update.group]?.append($0) }
                }
            case .remove:
                if (sets[update.group] != nil) {
                    sets[update.group]?.removeAll(where: { update.tags.contains($0) })
                } else {
                    adds[update.group]?.removeAll(where: { update.tags.contains($0) })
                    if (removes[update.group] == nil) {
                        removes[update.group] = []
                    }
                    update.tags.forEach { removes[update.group]?.append($0) }
                }
            case .set:
                removes[update.group] = nil
                adds[update.group] = nil
                sets[update.group] = update.tags
            }
        }
        
        let setUpdates = sets.map { TagGroupUpdate(group: $0.key, tags: Array($0.value), type: .set) }
        let addUpdates = adds.compactMap { $0.value.isEmpty ? nil : TagGroupUpdate(group: $0.key, tags: Array($0.value), type: .add) }
        let removeUpdates = removes.compactMap { $0.value.isEmpty ? nil : TagGroupUpdate(group: $0.key, tags: Array($0.value), type: .remove) }
        
        return setUpdates + addUpdates + removeUpdates
    }
    
    @objc(collapseAttributeUpdates:)
    public class func collapse(_ updates: [AttributeUpdate]) -> [AttributeUpdate] {
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
    
    @objc
    public class func applyTagUpdates(tagGroups: [String : [String]]?, tagGroupUpdates: [TagGroupUpdate]?) -> [String : [String]] {
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
    
    @objc
    public class func normalizeTags(_ tags: [String]) -> [String] {
        var normalized: [String] = []
        
        for tag in tags {
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            if (trimmed.isEmpty || trimmed.count > 128) {
                AirshipLogger.error("Tag \(trimmed) must be between 1-128 characters. Ignoring")
                continue
            }
            
            if (!normalized.contains(trimmed)) {
                normalized.append(trimmed)
            }
        }
        
        return normalized
    }
    
    @objc
    public class func normalizeTagGroup(_ group: String) -> String {
        return group.trimmingCharacters(in: .whitespacesAndNewlines)
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
