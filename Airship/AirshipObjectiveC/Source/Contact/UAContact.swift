/* Copyright Airship and Contributors */

public import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Airship contact. A contact is distinct from a channel and  represents a "user"
/// within Airship. Contacts may be named and have channels associated with it.
@objc
public final class UAContact: NSObject, Sendable {

    override init() {
        super.init()
    }

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
    public func editTagGroups() -> UATagGroupsEditor {
        let tagGroupsEditor = UATagGroupsEditor()
        tagGroupsEditor.editor = Airship.contact.editTagGroups()
        return tagGroupsEditor
    }

    @objc
    public func editTagGroups(_ editorBlock: (UATagGroupsEditor) -> Void) {
        let editor = editTagGroups()
        editorBlock(editor)
        editor.apply()
    }

    /// Begins an attribute editing session.
    /// - Returns: An AttributesEditor
    @objc
    public func editAttributes() -> UAAttributesEditor {
        let attributesEditor =  UAAttributesEditor()
        attributesEditor.editor = Airship.contact.editAttributes()
        return attributesEditor
    }

    @objc
    public func editAttributes(_ editorBlock: (UAAttributesEditor) -> Void) {
        let editor = editAttributes()
        editorBlock(editor)
        editor.apply()
    }

    /**
     * Associates a channel to the contact.
     * - Parameters:
     *   - channelID: The channel ID.
     *   - type: The channel type.
     */
    @objc
    public func associateChannel(_ channelID: String, type: UAChannelType) {
        Airship.contact.associateChannel(channelID, type: UAHelpers.toAirshipChannelType(type: type))
    }

    
    /// Begins a subscription list editing session
    /// - Returns: A Scoped subscription list editor
    @objc
    public func editSubscriptionLists() -> UAScopedSubscriptionListEditor {
        let subscriptionListEditor = UAScopedSubscriptionListEditor()
        subscriptionListEditor.editor = Airship.contact.editSubscriptionLists()
        return subscriptionListEditor
    }


    @objc
    public func editSubscriptionLists(_ editorBlock: (UAScopedSubscriptionListEditor) -> Void) {
        let editor = editSubscriptionLists()
        editorBlock(editor)
        editor.apply()
    }
}

@objc
/// Channel type
public enum UAChannelType: Int, Sendable, Equatable {

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
