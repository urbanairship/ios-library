/* Copyright Airship and Contributors */

/// Adds tags.
///
/// Expected argument values: `String` (single tag), `[String]` (single or multiple tags), or an object.
/// An example tag group JSON payload:
/// {
///     "channel": {
///         "channel_tag_group": ["channel_tag_1", "channel_tag_2"],
///         "other_channel_tag_group": ["other_channel_tag_1"]
///     },
///     "named_user": {
///         "named_user_tag_group": ["named_user_tag_1", "named_user_tag_2"],
///         "other_named_user_tag_group": ["other_named_user_tag_1"]
///     },
///     "device": [ "tag", "another_tag"]
/// }
///
///
/// Valid situations: `ActionSituation.foregroundPush`, `ActionSituation.launchedFromPush`
/// `ActionSituation.webViewInvocation`, `ActionSituation.foregroundInteractiveButton`,
/// `ActionSituation.backgroundInteractiveButton`, `ActionSituation.manualInvocation`, and
/// `ActionSituation.automation`
public final class AddTagsAction: AirshipAction {

    /// Default names - "add_tags_action", "^+t"
    public static let defaultNames: [String] = ["add_tags_action", "^+t"]

    /// Default predicate - rejects foreground pushes with visible display options
    public static let defaultPredicate: @Sendable (ActionArguments) -> Bool = { args in
        return args.metadata[ActionArguments.isForegroundPresentationMetadataKey] as? Bool != true
    }

    private let channel: @Sendable () -> any AirshipChannel
    private let contact: @Sendable () -> any AirshipContact
    
    private let tagMutationsChannel: AirshipAsyncChannel<TagActionMutation> = AirshipAsyncChannel<TagActionMutation>()
    
    public var tagMutations: AsyncStream<TagActionMutation> {
        get async {
            return await tagMutationsChannel.makeStream()
        }
    }

    
    public convenience init() {
        self.init(
            channel: Airship.componentSupplier(),
            contact: Airship.componentSupplier()
        )
    }

    init(
        channel: @escaping @Sendable () -> any AirshipChannel,
        contact: @escaping @Sendable () -> any AirshipContact
    ) {
        self.channel = channel
        self.contact = contact
    }


    public func accepts(arguments: ActionArguments) async -> Bool {
        guard arguments.situation != .backgroundPush else {
            return false
        }
        return true
    }

    public func perform(arguments: ActionArguments) async throws -> AirshipJSON? {
        let unwrapped = arguments.value.unWrap()
        if let tag = unwrapped as? String {
            channel().editTags { editor in
                editor.add(tag)
            }
            sendTagMutation(.channelTags([tag]))
        } else if let tags = arguments.value.unWrap() as? [String] {
            channel().editTags { editor in
                editor.add(tags)
            }
            sendTagMutation(.channelTags(tags))
        } else if let args: TagsActionsArgs = try arguments.value.decode() {
            if let channelTagGroups = args.channel {
                channel().editTagGroups { editor in
                    channelTagGroups.forEach { group, tags in
                        editor.add(tags, group: group)
                    }
                }
                
                sendTagMutation(.channelTagGroups(channelTagGroups))
            }

            if let contactTagGroups = args.namedUser {
                contact().editTagGroups { editor in
                    contactTagGroups.forEach { group, tags in
                        editor.add(tags, group: group)
                    }
                }
                sendTagMutation(.contactTagGroups(contactTagGroups))
            }

            if let deviceTags = args.device {
                channel().editTags() { editor in
                    editor.add(deviceTags)
                }
                sendTagMutation(.channelTags(deviceTags))
            }
        }
        return nil
    }
    
    private func sendTagMutation(_ mutation: TagActionMutation) {
        Task { @MainActor in
            await tagMutationsChannel.send(mutation)
        }
    }
}


