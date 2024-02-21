/* Copyright Airship and Contributors */

import Combine
import Foundation

/// Airship Channel protocol.
@objc(UAChannelProtocol)
public protocol AirshipBaseChannelProtocol: AnyObject, Sendable {
    /**
     * The Channel ID.
     */
    var identifier: String? { get }

    /**
     * Device tags
     */
    @objc
    var tags: [String] { get set }

    /**
     * Allows setting tags from the device. Tags can be set from either the server or the device, but
     * not both (without synchronizing the data), so use this flag to explicitly enable or disable
     * the device-side flags.
     *
     * Set this to `false` to prevent the device from sending any tag information to the server when using
     * server-side tagging. Defaults to `true`.
     */
    @objc
    var isChannelTagRegistrationEnabled: Bool { get set }

    /**
     * Edits channel tags.
     * - Returns: Tag editor.
     */
    @objc
    func editTags() -> TagEditor

    /**
     * Edits channel tags.
     * - Parameters:
     *   - editorBlock: The editor block with the editor. The editor will `apply` will be called after the block is executed.
     */
    @objc
    func editTags(_ editorBlock: (TagEditor) -> Void)

    /**
     * Edits channel tags groups.
     * - Returns: Tag group editor.
     */
    @objc
    func editTagGroups() -> TagGroupsEditor

    /**
     * Edits channel tag groups tags.
     * - Parameters:
     *   - editorBlock: The editor block with the editor. The editor will `apply` will be called after the block is executed.
     */
    @objc
    func editTagGroups(_ editorBlock: (TagGroupsEditor) -> Void)

    /**
     * Edits channel subscription lists.
     * - Returns: Subscription list editor.
     */
    @objc
    func editSubscriptionLists() -> SubscriptionListEditor

    /**
     * Edits channel subscription lists.
     * - Parameters:
     *   - editorBlock: The editor block with the editor. The editor will `apply` will be called after the block is executed.
     */
    @objc
    func editSubscriptionLists(_ editorBlock: (SubscriptionListEditor) -> Void)

    /**
     * Fetches current subscription lists.
     * - Returns: The subscription lists
     */
    @objc
    func fetchSubscriptionLists() async throws -> [String]

    /**
     * Edits channel attributes.
     * - Returns: Attribute editor.
     */
    @objc
    func editAttributes() -> AttributesEditor

    /**
     * Edits channel attributes.
     * - Parameters:
     *   - editorBlock: The editor block with the editor. The editor will `apply` will be called after the block is executed.
     */
    @objc
    func editAttributes(_ editorBlock: (AttributesEditor) -> Void)

    /**
     * Enables channel creation if channelCreationDelayEnabled was set to `YES` in the config.
     */
    @objc
    func enableChannelCreation()
}

#if canImport(ActivityKit)
import ActivityKit
#endif

/// Airship Channel protocol.
public protocol AirshipChannelProtocol: AirshipBaseChannelProtocol {
    /// Publishes edits made to the subscription lists through the SDK
    var subscriptionListEdits: AnyPublisher<SubscriptionListEdit, Never> { get }

#if canImport(ActivityKit)

    /// Gets an AsyncSequence of `LiveActivityRegistrationStatus` updates for a given live acitvity name.
    /// - Parameters:
    ///     - name: The live activity name
    /// - Returns A `LiveActivityRegistrationStatusUpdates`
    @available(iOS 16.1, *)
    func liveActivityRegistrationStatusUpdates(
        name: String
    ) -> LiveActivityRegistrationStatusUpdates

    /// Gets an AsyncSequence of `LiveActivityRegistrationStatus` updates for a given live acitvity ID.
    /// - Parameters:
    ///     - activity: The live activity
    /// - Returns A `LiveActivityRegistrationStatusUpdates`
    @available(iOS 16.1, *)
    func liveActivityRegistrationStatusUpdates<T: ActivityAttributes>(
        activity: Activity<T>
    ) -> LiveActivityRegistrationStatusUpdates

    /// Tracks a live activity with Airship for the given name.
    /// Airship will monitor the push token and status and automatically
    /// add and remove it from the channel for the App. If an activity is already
    /// tracked with the given name it will be replaced with the new activity.
    ///
    /// The name will be used to send updates through Airship. It can be unique
    /// for the device or shared across many devices.
    ///
    /// - Parameters:
    ///     - activity: The live activity
    ///     - name: The name of the activity
    @available(iOS 16.1, *)
    func trackLiveActivity<T: ActivityAttributes>(
        _ activity: Activity<T>,
        name: String
    )

    /// Called to restore live activity tracking. This method needs to be called exactly once
    /// during `application(_:didFinishLaunchingWithOptions:)` right
    /// after takeOff. Any activities not restored will stop being tracked by Airship.
    /// - Parameters:
    ///     - callback: Callback with the restorer.
    @available(iOS 16.1, *)
    func restoreLiveActivityTracking(
        callback: @escaping @Sendable (LiveActivityRestorer) async -> Void
    )

#endif
}

/// NOTE: For internal use only. :nodoc:
public protocol InternalAirshipChannelProtocol: AirshipChannelProtocol {
    func addRegistrationExtender(
        _ extender: @escaping (ChannelRegistrationPayload) async -> ChannelRegistrationPayload
    )

    func updateRegistration()

    func updateRegistration(forcefully: Bool)

    func clearSubscriptionListsCache()
}
