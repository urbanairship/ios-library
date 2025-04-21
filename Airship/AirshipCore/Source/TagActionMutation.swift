/* Copyright Airship and Contributors */

import Foundation

/// Tag mutations from `AddTagsAction` and `RemoveTagsAction`
public enum TagActionMutation: Sendable, Equatable {
    
    /// Represents a mutation for applying a set of tags to a channel.
    /// Associated value: A set of unique strings representing the tags to be applied to the channel
    case channelTags([String])
    
    /// Represents a mutation for applying tag group changes to the channel.
    /// Associated value: A map of tag group to tags.
    case channelTagGroups([String: [String]])
    
    /// Represents a mutation for applying tag group changes to the contact.
    /// Associated value: A map of tag group to tags.
    case contactTagGroups([String: [String]])
}
