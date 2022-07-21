import Foundation

@testable
import AirshipCore

@objc(UATestChannel)
public class TestChannel : NSObject, ChannelProtocol, Component {
    public var isComponentEnabled: Bool = true
    
    public var extenders: [((ChannelRegistrationPayload, @escaping (ChannelRegistrationPayload) -> Void) -> Void)] = []
    
    @objc
    public var identifier: String? = nil

    public var contactUpdates: [SubscriptionListUpdate] = []

    @objc
    public var updateRegistrationCalled : Bool = false
    
    @objc
    public var isChannelCreationEnabled: Bool = false
    
    public var pendingAttributeUpdates: [AttributeUpdate] = []
    
    public var pendingTagGroupUpdates: [TagGroupUpdate] = []
    
    public var tags: [String] = []
    
    public var isChannelTagRegistrationEnabled: Bool = false
    
    @objc
    public var tagGroupEditor : TagGroupsEditor?
    
    @objc
    public var attributeEditor : AttributesEditor?
    
    @objc
    public var subscriptionListEditor : SubscriptionListEditor?

    
    public func updateRegistration(forcefully: Bool) {
        self.updateRegistrationCalled = true
    }
    
    public func editTags() -> TagEditor {
        return TagEditor { applicator in
            self.tags = applicator(self.tags)
        }
    }
    
    public func editTags(_ editorBlock: (TagEditor) -> Void) {
        let editor = editTags()
        editorBlock(editor)
        editor.apply()
    }
    
    public func editTagGroups() -> TagGroupsEditor {
        return self.tagGroupEditor!
    }
    
    public func editTagGroups(_ editorBlock: (TagGroupsEditor) -> Void) {
        let editor = editTagGroups()
        editorBlock(editor)
        editor.apply()
    }
    
    public func editSubscriptionLists() -> SubscriptionListEditor {
        return self.subscriptionListEditor!
    }
    
    public func editSubscriptionLists(_ editorBlock: (SubscriptionListEditor) -> Void) {
        let editor = editSubscriptionLists()
        editorBlock(editor)
        editor.apply()
    }
    
    public func fetchSubscriptionLists(completionHandler: @escaping ([String]?, Error?) -> Void) -> Disposable {
        fatalError("Not implemented")
    }
    
    public func editAttributes() -> AttributesEditor {
        return self.attributeEditor!
    }
    
    public func editAttributes(_ editorBlock: (AttributesEditor) -> Void) {
        let editor = editAttributes()
        editorBlock(editor)
        editor.apply()
    }
    
    public func enableChannelCreation() {
        self.isChannelCreationEnabled = true
    }

    public func updateRegistration() {
        self.updateRegistrationCalled = true
    }
    
    public func addRegistrationExtender(_ extender: @escaping  (ChannelRegistrationPayload, (@escaping (ChannelRegistrationPayload) -> Void)) -> Void) {
        self.extenders.append(extender)
    }
    
    public override var description: String {
        return "TestChannel"
    }
    
    @objc
    public func extendPayload(_ payload: ChannelRegistrationPayload, completionHandler: @escaping (ChannelRegistrationPayload) -> Void) {
        Channel.extendPayload(payload,
                              extenders: self.extenders,
                              completionHandler: completionHandler)
    }

    public func processContactSubscriptionUpdates(_ updates: [SubscriptionListUpdate]) {
        self.contactUpdates.append(contentsOf: updates)
    }
}

extension TestChannel: InternalChannelProtocol {}
