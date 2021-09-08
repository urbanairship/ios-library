/* Copyright Airship and Contributors */

/**
 * This is the base class for AddTagsAction and RemoveTagsAction.
 */
@objc(UAModifyTagsAction)
public class ModifyTagsAction : NSObject, Action {
    static let namedUserKey = "named_user"
    static let channelKey = "channel"
    static let deviceKey = "device"
    
    private let channel: () -> ChannelProtocol
    private let contact: () -> ContactProtocol
    
    @objc
    public override convenience init() {
        self.init(channel: Channel.supplier,
                  contact: Contact.supplier)
    }
    
    @objc
    public init(channel: @escaping () -> ChannelProtocol,
                contact: @escaping () -> ContactProtocol) {
        self.channel = channel
        self.contact = contact
    }
    
    public func acceptsArguments(_ arguments: ActionArguments) -> Bool {
        guard arguments.situation != .backgroundPush else {
            return false
        }

        if arguments.value is String || arguments.value is [String] {
            return true
        }
        
        if let dict = arguments.value as? [String : Any] {
            let channelTagGroups = dict[ModifyTagsAction.channelKey]
            guard channelTagGroups == nil || channelTagGroups is [String : [String]] else {
                return false
            }
            
            let namedUserTagGroups = dict[ModifyTagsAction.namedUserKey]
            guard namedUserTagGroups == nil || namedUserTagGroups is [String : [String]] else {
                return false
            }
            
            let deviceTags = dict[ModifyTagsAction.deviceKey]
            guard deviceTags == nil || deviceTags is [String] else {
                return false
            }
            
            return deviceTags != nil || channelTagGroups != nil || deviceTags != nil
        }
        
        return false
    }

    public func perform(with arguments: ActionArguments, completionHandler: UAActionCompletionHandler) {
        let channel = self.channel()
        let contact = self.contact()
        
        if let tag = arguments.value as? String {
            let editor = channel.editTags()
            self.onChannelTags([tag], editor: editor)
            editor.apply()
        } else if let tags = arguments.value as? [String] {
            let editor = channel.editTags()
            self.onChannelTags(tags, editor: editor)
            editor.apply()
        } else if let dict = arguments.value as? [String : Any] {
            if let tags = dict[ModifyTagsAction.deviceKey] as? [String] {
                let editor = channel.editTags()
                self.onChannelTags(tags, editor: editor)
                editor.apply()
            }

            if let tagGroups = dict[ModifyTagsAction.channelKey] as? [String : [String]] {
                if (!tagGroups.isEmpty) {
                    let editor = channel.editTagGroups()
                    tagGroups.forEach { group, tags in
                        self.onChannelTags(tags, group: group, editor: editor)
                    }
                    editor.apply()
                }
            }
            
            if let tagGroups = dict[ModifyTagsAction.namedUserKey] as? [String : [String]] {
                if (!tagGroups.isEmpty) {
                    let editor = contact.editTagGroups()
                    tagGroups.forEach { group, tags in
                        self.onContactTags(tags, group: group, editor: editor)
                    }
                    editor.apply()
                }
            }
        }
            
        completionHandler(ActionResult.empty())
    }
    
    open func onChannelTags(_ tags: [String], editor: TagEditor) {}

    open func onChannelTags(_ tags: [String], group: String, editor: TagGroupsEditor) {}

    open func onContactTags(_ tags: [String], group: String, editor: TagGroupsEditor) {}
}
