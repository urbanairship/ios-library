/* Copyright Airship and Contributors */

public import Foundation
#if canImport(AirshipCore)
import AirshipCore
#endif

@objc
public final class UAChannel: NSObject, Sendable {

    @objc
    public func editTags() -> UATagEditor? {
        let tagEditor = UATagEditor()
        tagEditor.editor = Airship.channel.editTags()
        return tagEditor
    }
    
    @objc
    public func editTagGroups() -> UATagGroupsEditor? {
        let tagGroupsEditor = UATagGroupsEditor()
        tagGroupsEditor.editor = Airship.channel.editTagGroups()
        return tagGroupsEditor
    }
    
    @objc
    public func editSubscriptionLists() -> UASubscriptionListEditor? {
        let subscriptionListEditor = UASubscriptionListEditor()
        subscriptionListEditor.editor = Airship.channel.editSubscriptionLists()
        return subscriptionListEditor
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
    
    @objc(enableChannelCreation)
    public func enableChannelCreation() {
        Airship.channel.enableChannelCreation()
    }
    
}
