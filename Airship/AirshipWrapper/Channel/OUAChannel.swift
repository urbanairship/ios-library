/* Copyright Airship and Contributors */

import Foundation
public import AirshipCore


@objc
public class UAChannel: NSObject {
    
    @objc
    public func editTags() -> UATagEditor? {
        let tagEditor = UATagEditor()
        tagEditor.editor = Airship.channel.editTags()
        return tagEditor
    }
    
    @objc
    public func editTags(_ editorBlock: (TagEditor) -> Void) {
        Airship.channel.editTags(editorBlock)
    }
    
    @objc
    public func editTagGroups() -> UATagGroupsEditor? {
        let tagGroupsEditor = UATagGroupsEditor()
        tagGroupsEditor.editor = Airship.channel.editTagGroups()
        return tagGroupsEditor
    }
    
    @objc
    public func editTagGroups(_ editorBlock: (TagGroupsEditor) -> Void) {
        Airship.channel.editTagGroups(editorBlock)
    }
    
    @objc
    public func editSubscriptionLists() -> UASubscriptionListEditor? {
        let subscriptionListEditor = UASubscriptionListEditor()
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
    public func editAttributes() -> UAAttributesEditor? {
        let attributesEditor =  UAAttributesEditor()
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
