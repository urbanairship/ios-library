/* Copyright Airship and Contributors */

import Foundation
public import AirshipCore


@objc
public class OUAChannel: NSObject {
    
    @objc
    public func editTags() -> OUATagEditor? {
        let tagEditor = OUATagEditor()
        tagEditor.editor = Airship.channel.editTags()
        return tagEditor
    }
    
    @objc
    public func editTags(_ editorBlock: (TagEditor) -> Void) {
        Airship.channel.editTags(editorBlock)
    }
    
    @objc
    public func editTagGroups() -> OUATagGroupsEditor? {
        let tagGroupsEditor = OUATagGroupsEditor()
        tagGroupsEditor.editor = Airship.channel.editTagGroups()
        return tagGroupsEditor
    }
    
    @objc
    public func editTagGroups(_ editorBlock: (TagGroupsEditor) -> Void) {
        Airship.channel.editTagGroups(editorBlock)
    }
    
    @objc
    public func editSubscriptionLists() -> OUASubscriptionListEditor? {
        let subscriptionListEditor = OUASubscriptionListEditor()
        subscriptionListEditor.editor = Airship.channel.editSubscriptionLists()
        return subscriptionListEditor
    }
    
    @objc
    public func editSubscriptionLists(
        _ editorBlock: (SubscriptionListEditor) -> Void
    ) {
        Airship.channel.editSubscriptionLists(editorBlock)
    }
    
    @objc
    public func fetchSubscriptionLists() async throws -> [String] {
        try await Airship.channel.fetchSubscriptionLists()
    }
    
    @objc
    public func editAttributes() -> OUAAttributesEditor? {
        let attributesEditor =  OUAAttributesEditor()
        attributesEditor.editor = Airship.channel.editAttributes()
        return attributesEditor
    }
    
    @objc
    public func editAttributes(_ editorBlock: (AttributesEditor) -> Void) {
        Airship.channel.editAttributes(editorBlock)
    }
    
    @objc(enableChannelCreation)
    public func enableChannelCreation() {
        Airship.channel.enableChannelCreation()
    }
    
}
