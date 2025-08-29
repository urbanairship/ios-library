import Foundation

protocol ContactManagerProtocol: Actor, AuthTokenProvider {

    var contactUpdates: AsyncStream<ContactUpdate> { get }
    
    func onAudienceUpdated(onAudienceUpdatedCallback: (@Sendable (ContactAudienceUpdate) async -> Void)?)

    func addOperation(_ operation: ContactOperation)

    func generateDefaultContactIDIfNotSet() -> Void

    func currentNamedUserID() -> String?

    func setEnabled(enabled: Bool)

    func currentContactIDInfo() -> ContactIDInfo?

    func resetIfNeeded()

    func pendingAudienceOverrides(contactID: String) -> ContactAudienceOverrides
}

struct ContactAudienceUpdate: Equatable, Sendable {
    let contactID: String
    let tags: [TagGroupUpdate]?
    let attributes: [AttributeUpdate]?
    let subscriptionLists: [ScopedSubscriptionListUpdate]?
    let contactChannels: [ContactChannelUpdate]?

    init(contactID: String, tags: [TagGroupUpdate]? = nil, attributes: [AttributeUpdate]? = nil, subscriptionLists: [ScopedSubscriptionListUpdate]? = nil, contactChannels: [ContactChannelUpdate]? = nil) {
        self.contactID = contactID
        self.tags = tags
        self.attributes = attributes
        self.subscriptionLists = subscriptionLists
        self.contactChannels = contactChannels
    }
}

struct ContactIDInfo: Equatable, Sendable {
    let contactID: String
    let namedUserID: String?
    let isStable: Bool
    let resolveDate: Date

    init(contactID: String, isStable: Bool, namedUserID: String?, resolveDate: Date = Date.distantPast) {
        self.contactID = contactID
        self.isStable = isStable
        self.resolveDate = resolveDate
        self.namedUserID = namedUserID
    }
}

enum ContactUpdate: Equatable, Sendable {
    case contactIDUpdate(ContactIDInfo)
    case namedUserUpdate(String?)
    case conflict(ContactConflictEvent)
}

/// NOTE: For internal use only. :nodoc:
public struct StableContactInfo: Sendable, Equatable {
    public let contactID: String
    public let namedUserID: String?
    
    public init(contactID: String, namedUserID: String? = nil) {
        self.contactID = contactID
        self.namedUserID = namedUserID
    }
}

