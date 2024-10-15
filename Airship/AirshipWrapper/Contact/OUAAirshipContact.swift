/* Copyright Airship and Contributors */

import Foundation
public import AirshipCore

@objc
public class OUAAirshipContact: NSObject {
    
    /// Identifies the contact.
    /// - Parameter namedUserID: The named user ID.
    @objc
    public func identify(_ namedUserID: String) {
        Airship.contact.identify(namedUserID)
    }

    /// Resets the contact.
    @objc
    public func reset() {
        Airship.contact.reset()
    }

    /// Can be called after the app performs a remote named user association for the channel instead
    /// of using `identify` or `reset` through the SDK. When called, the SDK will refresh the contact
    /// data. Applications should only call this method when the user login has changed.
    @objc
    public func notifyRemoteLogin() {
        Airship.contact.notifyRemoteLogin()
    }

    /// Begins a tag groups editing session.
    /// - Returns: A TagGroupsEditor
    @objc
    public func editTagGroups() -> OUATagGroupsEditor? {
        let tagGroupsEditor = OUATagGroupsEditor()
        tagGroupsEditor.editor = Airship.contact.editTagGroups()
        return tagGroupsEditor
    }

    /// Begins an attribute editing session.
    /// - Returns: An AttributesEditor
    @objc
    public func editAttributes() -> OUAAttributesEditor? {
        let attributesEditor =  OUAAttributesEditor()
        attributesEditor.editor = Airship.contact.editAttributes()
        return attributesEditor
    }

    /**
     * Associates a channel to the contact.
     * - Parameters:
     *   - channelID: The channel ID.
     *   - type: The channel type.
     */
    @objc
    public func associateChannel(_ channelID: String, type: OUAChannelType) {
        if let type = ChannelType(rawValue: type.rawValue) {
            Airship.contact.associateChannel(channelID, type: type)
        }
    }

    
    /// Begins a subscription list editing session
    /// - Returns: A Scoped subscription list editor
    @objc
    public func editSubscriptionLists() -> OUAScopedSubscriptionListEditor {
        let subscriptionListEditor = OUAScopedSubscriptionListEditor()
        subscriptionListEditor.editor = Airship.contact.editSubscriptionLists()
        return subscriptionListEditor
    }

    /// Begins a subscription list editing session
    /// - Parameter editorBlock: A scoped subscription list editor block.
    /// - Returns: A ScopedSubscriptionListEditor
    @objc
    public func editSubscriptionLists(
        _ editorBlock: (ScopedSubscriptionListEditor) -> Void
    ) {
        Airship.contact.editSubscriptionLists(editorBlock)
    }
}

@objc
/// Channel type
public enum OUAChannelType: Int, Sendable, Equatable {

    /**
     * Email channel
     */
    case email

    /**
     * SMS channel
     */
    case sms

    /**
     * Open channel
     */
    case open
}
