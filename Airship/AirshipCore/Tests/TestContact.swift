import Foundation

@testable import AirshipCore

@objc(UATestContact)
public class TestContact: NSObject, ContactProtocol, Component {

    public var isComponentEnabled: Bool = true

    public var namedUserID: String?

    public var pendingAttributeUpdates: [AttributeUpdate] = []

    public var pendingTagGroupUpdates: [TagGroupUpdate] = []

    @objc
    public var tagGroupEditor: TagGroupsEditor?

    @objc
    public var attributeEditor: AttributesEditor?

    public var subscriptionListEditor: ScopedSubscriptionListEditor?

    public func identify(_ namedUserID: String) {
        self.namedUserID = namedUserID
    }

    public func reset() {
        self.namedUserID = nil
    }

    public func editTagGroups() -> TagGroupsEditor {
        return tagGroupEditor!
    }

    public func editAttributes() -> AttributesEditor {
        return attributeEditor!
    }

    public func editTagGroups(_ editorBlock: (TagGroupsEditor) -> Void) {
        let editor = editTagGroups()
        editorBlock(editor)
        editor.apply()
    }

    public func editAttributes(_ editorBlock: (AttributesEditor) -> Void) {
        let editor = editAttributes()
        editorBlock(editor)
        editor.apply()
    }

    public func registerEmail(
        _ address: String,
        options: EmailRegistrationOptions
    ) {
        // TODO
    }

    public func registerSMS(_ msisdn: String, options: SMSRegistrationOptions) {
        // TODO
    }

    public func registerOpen(
        _ address: String,
        options: OpenRegistrationOptions
    ) {
        // TODO
    }

    public func associateChannel(_ channelID: String, type: ChannelType) {
        // TODO
    }

    public func editSubscriptionLists() -> ScopedSubscriptionListEditor {
        return subscriptionListEditor!
    }

    public func editSubscriptionLists(
        _ editorBlock: (ScopedSubscriptionListEditor) -> Void
    ) {
        let editor = editSubscriptionLists()
        editorBlock(editor)
        editor.apply()
    }

    public func fetchSubscriptionLists(
        completionHandler: @escaping ([String: ChannelScopes]?, Error?) -> Void
    ) -> Disposable {
        return Disposable()
    }
}
