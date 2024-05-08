/* Copyright Airship and Contributors */

import Combine


/// Airship contact. A contact is distinct from a channel and  represents a "user"
/// within Airship. Contacts may be named and have channels associated with it.
@objc(UAContactProtocol)
public protocol AirshipBaseContactProtocol: AnyObject, Sendable {
    /**
     * The current named user ID if set through the SDK.
     */
    @objc(getNamedUserIDWithCompletionHandler:)
    func _getNamedUserID() async -> String?

    /**
     * Associates the contact with the given named user identifier.
     * The named user ID must be between 1 and 128 characters
     * - Parameters:
     *   - namedUserID: The named user ID.
     */
    @objc
    func identify(_ namedUserID: String)

    /**
     * Disassociate the channel from its current contact, and create a new
     * un-named contact.
     */
    @objc
    func reset()

    /**
     * Can be called after the app performs a remote named user association for the channel instead
     * of using `identify` or `reset` through the SDK. When called, the SDK will refresh the contact
     * data. Applications should only call this method when the user login has changed.
     */
    @objc
    func notifyRemoteLogin()

    /**
     * Edits tags.
     * - Returns: A tag groups editor.
     */
    @objc
    func editTagGroups() -> TagGroupsEditor

    /**
     * Edits tags.
     * - Parameters:
     *   - editorBlock: The editor block with the editor. The editor will `apply` will be called after the block is executed.
     */
    @objc
    func editTagGroups(_ editorBlock: (TagGroupsEditor) -> Void)

    /**
     * Edits attributes.
     * - Returns: An attributes editor.
     */
    @objc
    func editAttributes() -> AttributesEditor

    /**
     * Edits  attributes.
     * - Parameters:
     *   - editorBlock: The editor block with the editor. The editor will `apply` will be called after the block is executed.
     */
    @objc
    func editAttributes(_ editorBlock: (AttributesEditor) -> Void)

    /**
     * Associates an Email channel to the contact.
     * - Parameters:
     *   - address: The email address.
     *   - options: The email channel registration options.
     */
    @objc
    func registerEmail(_ address: String, options: EmailRegistrationOptions)

    /**
     * Associates a SMS channel to the contact.
     * - Parameters:
     *   - msisdn: The SMS msisdn.
     *   - options: The SMS channel registration options.
     */
    @objc
    func registerSMS(_ msisdn: String, options: SMSRegistrationOptions)

    /**
     * Associates an Open channel to the contact.
     * - Parameters:
     *   - address: The open channel address.
     *   - options: The open channel registration options.
     */
    @objc
    func registerOpen(_ address: String, options: OpenRegistrationOptions)

    /**
     * Associates a channel to the contact.
     * - Parameters:
     *   - channelID: The channel ID.
     *   - type: The channel type.
     */
    @objc
    func associateChannel(_ channelID: String, type: ChannelType)

    /// Begins a subscription list editing session
    /// - Returns: A Scoped subscription list editor
    @objc
    func editSubscriptionLists() -> ScopedSubscriptionListEditor

    /// Begins a subscription list editing session
    /// - Parameter editorBlock: A scoped subscription list editor block.
    @objc
    func editSubscriptionLists(
        _ editorBlock: (ScopedSubscriptionListEditor) -> Void
    )

    /// Fetches subscription lists.
    /// - Returns: Subscriptions lists.
    @objc(fetchSubscriptionListsWithCompletionHandler:)
    func _fetchSubscriptionLists() async throws ->  [String: ChannelScopes]
}

/// Airship contact. A contact is distinct from a channel and  represents a "user"
/// within Airship. Contacts may be named and have channels associated with it.
public protocol AirshipContactProtocol: AirshipBaseContactProtocol {
    /// Current named user ID
    var namedUserID: String? { get async }

    /// The named user ID current value publisher.
    var namedUserIDPublisher: AnyPublisher<String?, Never> { get }

    /// Conflict event publisher
    var conflictEventPublisher: AnyPublisher<ContactConflictEvent, Never> { get }

    /// Notifies any edits to the subscription lists.
    var subscriptionListEdits: AnyPublisher<ScopedSubscriptionListEdit, Never> { get }

    /// Fetches subscription lists.
    /// - Returns: Subscriptions lists.
    func fetchSubscriptionLists() async throws ->  [String: [ChannelScope]]

    /// SMS validator delegate to allow overriding the default SMS validation
    /// - Returns: Bool indicating if SMS is valid.
    var smsValidatorDelegate: SMSValidatorDelegate? { get set }

    /**
     * Validates MSISDN
     * - Parameters:
     *   - msisdn: The mobile phone number to validate.
     *   - sender: The identifier given to the sender of the SMS message.
     */
    func validateSMS(_ msisdn: String, sender: String) async throws -> Bool

    /**
     * Re-sends the double opt in prompt via the channel
     * - Parameters:
     *   - channel: The channel to resend the double opt-in prompt to
     */
    func resend(_ channel: ContactChannel)

    /**
     * Opts out and disassociates channel
     * - Parameters:
     *   - channel: The channel to opt-out and disassociate
     */
    func disassociateChannel(_ channel: ContactChannel)

    var contactChannelUpdates: AsyncStream<[ContactChannel]> { get async throws }
    var contactChannelPublisher: AnyPublisher<[ContactChannel], Never> { get async throws }
}


protocol InternalAirshipContactProtocol: AirshipContactProtocol {
    var contactID: String? { get async }
    var authTokenProvider: AuthTokenProvider { get }

    func getStableContactID() async -> String

    var contactIDInfo: ContactIDInfo? { get async }
    var contactIDUpdates: AnyPublisher<ContactIDInfo, Never> { get }
}
