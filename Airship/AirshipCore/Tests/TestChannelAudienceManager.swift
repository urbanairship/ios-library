import Foundation

@testable
import AirshipCore

@objc(UATestChannelAudienceManager)
public class TestChannelAudienceManager : NSObject, ChannelAudienceManagerProtocol {
    public var pendingAttributeUpdates: [AttributeUpdate] = []
    
    public var pendingTagGroupUpdates: [TagGroupUpdate] = []
    
    public var channelID: String? = nil
    
    public var enabled: Bool = false
    
    @objc
    public var tagGroupEditor : TagGroupsEditor?
    
    @objc
    public var attributeEditor : AttributesEditor?
    
    @objc
    public var subcriptionListEditor : SubscriptionListEditor?
    
    @objc
    public var fetchSubscriptionListCallback: ((([String]?, Error?) -> Void) -> UADisposable)?

    
    public func editSubscriptionLists() -> SubscriptionListEditor {
        return subcriptionListEditor!
    }
    
    public func editTagGroups(allowDeviceGroup: Bool) -> TagGroupsEditor {
        return tagGroupEditor!
    }
    
    public func editAttributes() -> AttributesEditor {
        return attributeEditor!
    }
    
    public func fetchSubscriptionLists(completionHandler: @escaping ([String]?, Error?) -> Void) -> UADisposable {
        return fetchSubscriptionListCallback!(completionHandler)
    }
}
