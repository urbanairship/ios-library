/* Copyright Airship and Contributors */


import Foundation

/// Modify channel or contact tags.
///
/// Expected argument values: an array of mutations.
/// An example add channel tags JSON payload:
/// [
///     {
///       "action": "add",
///       "tags": [
///         "channel_tag_1",
///         "channel_tag_2"
///       ],
///       "type": "channel"
///     },
///     {
///       "action": "remove",
///       "group": "tag_group"
///       "tags": [
///         "contact_tag_1",
///         "contact_tag_2"
///       ],
///       "type": "contact"
///     }
/// ]
///
///
/// Valid situations: `ActionSituation.foregroundPush`, `ActionSituation.launchedFromPush`
/// `ActionSituation.webViewInvocation`, `ActionSituation.foregroundInteractiveButton`,
/// `ActionSituation.backgroundInteractiveButton`, `ActionSituation.manualInvocation`, and
/// `ActionSituation.automation`
public final class ModifyTagsAction: AirshipAction {
    
    /// Default names - "tag_action", "^t"
    public static let defaultNames = ["tag_action", "^t"]
    
    /// Default predicate - rejects foreground pushes with visible display options
    public static let defaultPredicate: @Sendable (ActionArguments) -> Bool = { args in
        return args.metadata[ActionArguments.isForegroundPresentationMetadataKey] as? Bool != true
    }
    
    private let channel: @Sendable () -> any AirshipChannelProtocol
    private let contact: @Sendable () -> any AirshipContactProtocol
    
    init(
        channel: @escaping @Sendable () -> any AirshipChannelProtocol,
        contact: @escaping @Sendable () -> any AirshipContactProtocol
    ) {
        self.channel = channel
        self.contact = contact
    }
    
    public convenience init() {
        self.init(
            channel: Airship.componentSupplier(),
            contact: Airship.componentSupplier()
        )
    }
    
    public func accepts(arguments: ActionArguments) async -> Bool {
        guard arguments.situation != .backgroundPush else {
            return false
        }
        return true
    }
    
    public func perform(arguments: ActionArguments) async throws -> AirshipJSON? {
        let data: [Arguments] = try arguments.value.decode()
        
        let channelEditor = self.channel().editTags()
        let channelGroupEditor = self.channel().editTagGroups()
        let contactGroupEditor = self.contact().editTagGroups()
        var onDoneCallbacks: [EditorType: () -> Void] = [:]
        
        for data in data {
            performAction(
                data: data,
                channelEditor: {
                    if !onDoneCallbacks.keys.contains(.channel) {
                        onDoneCallbacks[.channel] = channelEditor.apply
                    }
                    return channelEditor
                }) { target in
                    let key: EditorType
                    let editor: TagGroupsEditor
                    
                    switch target {
                    case .channel:
                        key = .channelGroup
                        editor = channelGroupEditor
                    case .contact:
                        key = .contactGroup
                        editor = contactGroupEditor
                    }
                    
                    if !onDoneCallbacks.keys.contains(key) {
                        onDoneCallbacks[key] = editor.apply
                    }
                    
                    return editor
                }
        }
        
        onDoneCallbacks.values.forEach { $0() }
        
        return nil
    }
    
    private func performAction(
        data: Arguments,
        channelEditor: () -> TagEditor,
        groupEditor: (Arguments.Target) -> TagGroupsEditor
    ) {
        switch data {
        case .channel(let args):
            if let group = args.group {
                let editor = groupEditor(.channel)
                
                switch args.action {
                case .add: editor.add(args.tags, group: group)
                case .remove: editor.remove(args.tags, group: group)
                }
            } else {
                let editor = channelEditor()
                
                switch args.action {
                case .add: editor.add(args.tags)
                case .remove: editor.remove(args.tags)
                }
            }
        case .contact(let args):
            let editor = groupEditor(.contact)
            
            switch args.action {
            case .add: editor.add(args.tags, group: args.group)
            case .remove: editor.remove(args.tags, group: args.group)
            }
        }
    }
    
    private enum EditorType: Hashable {
        case channel, channelGroup, contactGroup
    }
    
    private enum Arguments: Codable, Sendable {
        
        case channel(ChannelTags)
        case contact(ContactTags)
        
        private enum CodingKeys : String, CodingKey, Sendable {
            case type
        }
        
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            switch try container.decode(Target.self, forKey: .type) {
            case .channel:
                self = try .channel(.init(from: decoder))
            case .contact:
                self = try .contact(.init(from: decoder))
            }
        }
        
        func encode(to encoder: any Encoder) throws {
            switch self {
            case .channel(let value):
                try value.encode(to: encoder)
            case .contact(let value):
                try value.encode(to: encoder)
            }
        }
        
        enum Target: String, Codable, Sendable {
            case channel = "channel"
            case contact = "contact"
        }
        
        enum ActionType: String, Codable, Sendable {
            case add = "add"
            case remove = "remove"
        }
        
        struct ChannelTags: Codable, Sendable {
            let type: Target = .channel
            let group: String?
            let action: ActionType
            let tags: [String]
            
            enum CodingKeys : String, CodingKey, Sendable {
                case group
                case action
                case tags
                case type
            }
        }
        
        struct ContactTags: Codable, Sendable {
            let type: Target = .contact
            let group: String
            let action: ActionType
            let tags: [String]
            
            enum CodingKeys : String, CodingKey, Sendable {
                case group
                case action
                case tags
                case type
            }
        }
    }
}
