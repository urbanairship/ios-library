import Foundation
import ActivityKit

@testable import AirshipCore
import Combine

class TestChannel: NSObject, AirshipChannelProtocol, AirshipComponent, @unchecked Sendable {
    var identifierUpdates: AsyncStream<String> {
        return AsyncStream { _ in }
    }

    private let subscriptionListEditsSubject = PassthroughSubject<SubscriptionListEdit, Never>()

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

    public var identifier: String? = nil

    public var contactUpdates: [SubscriptionListUpdate] = []

    public var updateRegistrationCalled: Bool = false

    public var isChannelCreationEnabled: Bool = false

    public var pendingAttributeUpdates: [AttributeUpdate] = []

    public var pendingTagGroupUpdates: [TagGroupUpdate] = []

    public var tags: [String] = []

    public var isChannelTagRegistrationEnabled: Bool = false

    public var tagGroupEditor: TagGroupsEditor?
    
    public var attributeEditor: AttributesEditor?

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


    public var subscriptionListEdits: AnyPublisher<SubscriptionListEdit, Never> {
        subscriptionListEditsSubject.eraseToAnyPublisher()
    }


    func liveActivityRegistrationStatusUpdates(name: String) -> LiveActivityRegistrationStatusUpdates {
        return LiveActivityRegistrationStatusUpdates { _ in
            return .notTracked
        }
    }

    @available(iOS 16.1, *)
    func liveActivityRegistrationStatusUpdates<T>(activity: Activity<T>) -> LiveActivityRegistrationStatusUpdates where T : ActivityAttributes {
        return LiveActivityRegistrationStatusUpdates { _ in
            return .notTracked
        }
    }

    @available(iOS 16.1, *)
    func trackLiveActivity<T>(_ activity: Activity<T>, name: String) where T : ActivityAttributes {

    }

    @available(iOS 16.1, *)
    func restoreLiveActivityTracking(callback: @escaping @Sendable (AirshipCore.LiveActivityRestorer) async -> Void) {

    }

}

extension TestChannel: InternalAirshipChannelProtocol {
    func clearSubscriptionListsCache() {
        
    }
}
