/* Copyright Airship and Contributors */

/**
 * This is the base class for AddTagsAction and RemoveTagsAction.
 */
@objc(UAModifyTagsAction)
public class ModifyTagsAction : NSObject, UAAction {
    static let namedUserKey = "named_user"
    static let channelKey = "channel"
    static let deviceKey = "device"
    
    public func acceptsArguments(_ arguments: UAActionArguments) -> Bool {
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

    public func perform(with arguments: UAActionArguments, completionHandler: UAActionCompletionHandler) {
        guard let channel = UAirship.channel(),
              let contact = UAirship.contact() else {
            completionHandler(UAActionResult(error: AirshipErrors.error("Takeoff not called")))
            return
        }
        
        if let tag = arguments.value as? String {
            self.onChannelTags([tag], channel: channel)
            channel.updateRegistration()
        } else if let tags = arguments.value as? [String] {
            self.onChannelTags(tags, channel: channel)
            channel.updateRegistration()
        } else if let dict = arguments.value as? [String : Any] {
            if let deviceTags = dict[ModifyTagsAction.deviceKey] as? [String] {
                self.onChannelTags(deviceTags, channel: channel)
                channel.updateRegistration()
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
            
        completionHandler(UAActionResult.empty())
    }
    
    open func onChannelTags(_ tags: [String], channel: UAChannel) {}

    open func onChannelTags(_ tags: [String], group: String, editor: TagGroupsEditor) {}

    open func onContactTags(_ tags: [String], group: String, editor: TagGroupsEditor) {}
}
