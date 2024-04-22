import Foundation
import Combine

@testable import AirshipCore

class TestContact: InternalAirshipContactProtocol, AirshipComponent, @unchecked Sendable {


    private let channelsListSubject = PassthroughSubject<ChannelRegistrationState, Never>()
    public var channelsListPublisher: AnyPublisher<ChannelRegistrationState, Never> {
        channelsListSubject.eraseToAnyPublisher()
    }

    let channelOptinStatusSubject = PassthroughSubject<[AirshipChannelOptinStatus], Never>()
    var channelOptinStatusPublisher: AnyPublisher<[AirshipChannelOptinStatus], Never> {
        channelOptinStatusSubject.eraseToAnyPublisher()
    }

    var SMSValidatorDelegate: SMSValidatorDelegate?
    func validateSMS(_ msisdn: String, sender: String) async throws -> Bool {
        true
    }

    var channelOptinStatus: [AirshipChannelOptinStatus]? = nil
    
    func fetchAssociatedChannelsList() async -> [AssociatedChannel]? {
        return nil
    }
    
    func checkOptinStatus() async -> [AirshipChannelOptinStatus]? {
        return nil
    }
    
    private let channelRegistrationEditSubject = PassthroughSubject<ChannelRegistrationState, Never>()
    var channelRegistrationEditPublisher: AnyPublisher<ChannelRegistrationState, Never> {
        channelRegistrationEditSubject.eraseToAnyPublisher()
    }

    func notifyRemoteLogin() {

    }

    var contactIDInfo: AirshipCore.ContactIDInfo? = nil

    let contactIDUpdatesSubject = PassthroughSubject<ContactIDInfo, Never>()
    var contactIDUpdates: AnyPublisher<ContactIDInfo, Never>  {
        contactIDUpdatesSubject.eraseToAnyPublisher()
    }

    var contactID: String? = nil

    var authTokenProvider: AuthTokenProvider = TestAuthTokenProvider { id in
        return ""
    }

    func getStableContactID() async -> String {
        return contactID ?? ""
    }

    @objc
    public static let contactConflictEvent = NSNotification.Name(
        "com.urbanairship.contact_conflict"
    )

    @objc
    public static let contactConflictEventKey = "event"

    @objc
    public static let maxNamedUserIDLength = 128


    private let conflictEventSubject = PassthroughSubject<ContactConflictEvent, Never>()
    public var conflictEventPublisher: AnyPublisher<ContactConflictEvent, Never> {
        conflictEventSubject.eraseToAnyPublisher()
    }
    

    private let namedUserUpdatesSubject = PassthroughSubject<String?, Never>()
    public var namedUserIDPublisher: AnyPublisher<String?, Never> {
        namedUserUpdatesSubject
            .prepend(namedUserID)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    public var subscriptionListEdits: AnyPublisher<AirshipCore.ScopedSubscriptionListEdit, Never> {
        subscriptionListEditsSubject.eraseToAnyPublisher()
    }
    private let subscriptionListEditsSubject = PassthroughSubject<ScopedSubscriptionListEdit, Never>()

    public func _getNamedUserID() async -> String? {
        return self.namedUserID
    }


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

    public func registerSMS(
        _ msisdn: String,
        options: SMSRegistrationOptions
    ) {
        // TODO
    }

    func validateSMS(
        _ msisdn: String,
        sender: String
    ) {
        // TODO
    }
    
    public func registerOpen(
        _ address: String,
        options: OpenRegistrationOptions
    ) {
        // TODO
    }

    public func associateChannel(_ channelID: String, type: ChannelType, options: RegistrationOptions) {
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

    public func fetchSubscriptionLists() async throws ->  [String: [ChannelScope]] {
        return [:]
    }

    public func _fetchSubscriptionLists() async throws ->  [String: ChannelScopes] {
        return [:]
    }
    
    func optOutChannel(_ channelID: String) {
        //
    }
}
