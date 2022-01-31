/* Copyright Airship and Contributors */

import Foundation

// NOTE: For internal use only. :nodoc:
@objc(UAAudienceUtils)
public class AudienceUtils : NSObject {
    
    class func collapse(_ updates: [ScopedSubscriptionListUpdate]) -> [ScopedSubscriptionListUpdate] {
        var handled = Set<String>()
        var collapsed: [ScopedSubscriptionListUpdate] = []
        
        updates.reversed().forEach { update in
            let key = "\(update.scope.rawValue):\(update.listId)"
            if (!handled.contains(key)) {
                collapsed.append(update)
                handled.insert(key)
            }
        }
        
        return collapsed.reversed()
    }
        
    class func collapse(_ updates: [SubscriptionListUpdate]) -> [SubscriptionListUpdate] {
        var handled = Set<String>()
        var collapsed: [SubscriptionListUpdate] = []
        
        updates.reversed().forEach { update in
            if (!handled.contains(update.listId)) {
                collapsed.append(update)
                handled.insert(update.listId)
            }
        }
        
        return collapsed.reversed()
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
    public class func applyTagUpdates(_ tagGroups: [String : [String]]?, updates: [TagGroupUpdate]?) -> [String : [String]] {
        var updated = tagGroups ?? [:]
        
        updates?.forEach { update in
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
    
    class func applyAttributeUpdates(_ attributes: [String : JsonValue]?, updates: [AttributeUpdate]?) -> [String : JsonValue] {
        var updated = attributes ?? [:]
        
        updates?.forEach { update in
            switch(update.type) {
            case .set:
                updated[update.attribute] = update.jsonValue
            case .remove:
                updated[update.attribute] = nil
            }
        }
        
        return updated
    }
    
    class func wrap(_ scopedSubscriptionLists: [String: [ChannelScope]]) -> [String : ChannelScopes] {
        scopedSubscriptionLists.mapValues { ChannelScopes($0) }
    }
    
    class func applySubscriptionListsUpdates(_ subscriptionLists: [String: [ChannelScope]]?,
                                             updates: [ScopedSubscriptionListUpdate]?) -> [String: [ChannelScope]] {
        var updated = subscriptionLists ?? [:]
        updates?.forEach { update in
            var scopes = updated[update.listId] ?? []
            switch(update.type) {
            case .subscribe:
                if (!scopes.contains(update.scope)) {
                    scopes.append(update.scope)
                    updated[update.listId] = scopes
                }
            case .unsubscribe:
                scopes.removeAll(where: { $0 == update.scope })
                updated[update.listId] = scopes.isEmpty ? nil : scopes
            }
        }
        
        return updated
    }
}
