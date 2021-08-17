/* Copyright Airship and Contributors */

/**
 * Adds tags. This Action is registered under the
 * names ^+t and "add_tags_action".
 *
 * Expected argument values: NSString (single tag), NSArray (single or multiple tags), or NSDictionary (tag groups).
 * An example tag group JSON payload:
 * {
 *     "channel": {
 *         "channel_tag_group": ["channel_tag_1", "channel_tag_2"],
 *         "other_channel_tag_group": ["other_channel_tag_1"]
 *     },
 *     "named_user": {
 *         "named_user_tag_group": ["named_user_tag_1", "named_user_tag_2"],
 *         "other_named_user_tag_group": ["other_named_user_tag_1"]
 *     },
 *     "device": [ "tag", "another_tag"]
 * }
 *
 *
 * Valid situations: UASituationForegroundPush, UASituationLaunchedFromPush
 * UASituationWebViewInvocation, UASituationForegroundInteractiveButton,
 * UASituationBackgroundInteractiveButton, UASituationManualInvocation, and
 * UASituationAutomation
 *
 * Default predicate: Rejects foreground pushes with visible display options
 *
 * Result value: nil
 *
 * Error: nil
 *
 * Fetch result: UAActionFetchResultNoData
 */
@objc(UAAddTagsAction)
public class AddTagsAction : ModifyTagsAction {
    
    @objc
    public static let name = "add_tags_action"
    
    @objc
    public static let shortName = "^+t"
    
    public override func onChannelTags(_ tags: [String], editor: TagEditor) {
        editor.add(tags)
    }
    
    public override func onChannelTags(_ tags: [String], group: String, editor: TagGroupsEditor) {
        editor.add(tags, group: group)
    }
    
    public override func onContactTags(_ tags: [String], group: String, editor: TagGroupsEditor) {
        editor.add(tags, group: group)
    }
}
