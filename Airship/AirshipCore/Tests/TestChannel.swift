import Foundation

@testable import AirshipCore

class TestChannel: NSObject, BaseAirshipChannelProtocol, AirshipComponent, @unchecked Sendable {

    public var isComponentEnabled: Bool = true

    public var extenders: [(ChannelRegistrationPayload) async -> ChannelRegistrationPayload] = []

    public var channelPayload: ChannelRegistrationPayload {
        get async {
            var result: ChannelRegistrationPayload = ChannelRegistrationPayload()

            for extender in extenders {
                result = await extender(result)
            }
            return result
        }
    }

    @objc
    public var identifier: String? = nil

    public var contactUpdates: [SubscriptionListUpdate] = []

    @objc
    public var updateRegistrationCalled: Bool = false

    @objc
    public var isChannelCreationEnabled: Bool = false

    public var pendingAttributeUpdates: [AttributeUpdate] = []

    public var pendingTagGroupUpdates: [TagGroupUpdate] = []

    public var tags: [String] = []

    public var isChannelTagRegistrationEnabled: Bool = false

    @objc
    public var tagGroupEditor: TagGroupsEditor?
    
    @objc
    public var attributeEditor: AttributesEditor?

    @objc
    public var subscriptionListEditor: SubscriptionListEditor?

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

    public func editSubscriptionLists(
        _ editorBlock: (SubscriptionListEditor) -> Void
    ) {
        let editor = editSubscriptionLists()
        editorBlock(editor)
        editor.apply()
    }

    public func fetchSubscriptionLists() async throws -> [String] {
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

    public override var description: String {
        return "TestChannel"
    }

    public func addRegistrationExtender(_ extender: @escaping (AirshipCore.ChannelRegistrationPayload) async -> AirshipCore.ChannelRegistrationPayload) {
        self.extenders.append(extender)
    }

    public func processContactSubscriptionUpdates(
        _ updates: [SubscriptionListUpdate]
    ) {
        self.contactUpdates.append(contentsOf: updates)
    }
}

extension TestChannel: InternalAirshipChannelProtocol {
    func clearSubscriptionListsCache() {
        
    }
}
extension TestChannel: AirshipChannelProtocol {

}
