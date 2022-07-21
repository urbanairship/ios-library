/* Copyright Airship and Contributors */

import Foundation

/**
 * Airship Channel protocol.
 */
@objc(UAChannelProtocol)
public protocol ChannelProtocol {
    
    /**
     * The Channel ID.
     */
    var identifier : String? { get }

    // NOTE: For internal use only. :nodoc:
    @objc
    var pendingAttributeUpdates : [AttributeUpdate] { get }
        
    // NOTE: For internal use only. :nodoc:
    @objc
    var pendingTagGroupUpdates : [TagGroupUpdate] { get }

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
    var isChannelTagRegistrationEnabled : Bool  { get set }
    
    /**
     * Updates channel registration if needed. Appications should not need to call this method.
     */
    @objc
    func updateRegistration()
    
    // NOTE: For internal use only. :nodoc:
    @objc(updateRegistrationForcefully:)
    func updateRegistration(forcefully: Bool)
    
    // NOTE: For internal use only. :nodoc:
    @objc
    func addRegistrationExtender(_ extender: @escaping  (ChannelRegistrationPayload, (@escaping (ChannelRegistrationPayload) -> Void)) -> Void)
    
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
     * Edits channel subcription lists.
     * - Returns: Subcription list editor.
     */
    @objc
    func editSubscriptionLists() -> SubscriptionListEditor
    
    /**
     * Edits channel subcription lists.
     * - Parameters:
     *   - editorBlock: The editor block with the editor. The editor will `apply` will be called after the block is executed.
     */
    @objc
    func editSubscriptionLists(_ editorBlock: (SubscriptionListEditor) -> Void)
    
    /**
     * Fetches current subscription lists.
     * - Parameters:
     *   - completionHandler: The completion handler with the result.
     * - Returns: A disposable to cancel the callback.
     */
    @objc
    @discardableResult
    func fetchSubscriptionLists(completionHandler: @escaping ([String]?, Error?) -> Void) -> Disposable
    
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

protocol InternalChannelProtocol : ChannelProtocol {
    func processContactSubscriptionUpdates(_ updates: [SubscriptionListUpdate])
}


