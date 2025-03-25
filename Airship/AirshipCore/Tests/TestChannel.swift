import Foundation
import ActivityKit

@testable
import AirshipCore
import Combine

class TestChannel: NSObject, AirshipChannelProtocol, AirshipComponent, @unchecked Sendable {
    private var identifierSubject: CurrentValueSubject<String?, Never> = CurrentValueSubject(nil)

    var identifierUpdates: AsyncStream<String> {
        return AsyncStream { continuation in
            let cancellable = identifierSubject
                .compactMap { $0 }
                .removeDuplicates()
                .sink { update in
                    continuation.yield(update) 
                }

            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }

    private let subscriptionListEditsSubject = PassthroughSubject<SubscriptionListEdit, Never>()

    public var extenders: [@Sendable (inout ChannelRegistrationPayload) async -> Void] = []

    public var channelPayload: ChannelRegistrationPayload {
        get async {
            var result: ChannelRegistrationPayload = ChannelRegistrationPayload()

            for extender in extenders {
                await extender(&result)
            }
            return result
        }
    }

    @objc
    public var identifier: String? = nil {
        didSet {
            identifierSubject.send(identifier)
        }
    }

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

    public func addRegistrationExtender(
        _ extender: @Sendable @escaping (inout ChannelRegistrationPayload) async -> Void
    ) {
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
