import Foundation

protocol ContactManagerProtocol: Actor, AuthTokenProvider {

    var contactUpdates: AsyncStream<ContactUpdate> { get }

    func onAudienceUpdated(onAudienceUpdatedCallback: (@Sendable (ContactAudienceUpdate) async -> Void)?)
    func addOperation(_ operation: ContactOperation)

    func generateDefaultContactIDIfNotSet() -> Void

    func currentNamedUserID() -> String?

    func setEnabled(enabled: Bool)

    func currentContactIDInfo() -> ContactIDInfo?

    func pendingAudienceOverrides(contactID: String) -> ContactAudienceOverrides
}

struct ContactAudienceUpdate: Equatable, Sendable {
    let contactID: String
    let tags: [TagGroupUpdate]?
    let attributes: [AttributeUpdate]?
    let subscriptionLists: [ScopedSubscriptionListUpdate]?
}

struct ContactIDInfo: Equatable, Sendable {
    let contactID: String
    let isStable: Bool
}

enum ContactUpdate: Equatable, Sendable {
    case contactIDUpdate(ContactIDInfo)
    case namedUserUpdate(String?)
    case conflict(ContactConflictEvent)
}
