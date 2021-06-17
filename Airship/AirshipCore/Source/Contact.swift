/* Copyright Airship and Contributors */

import Foundation

/**
 * Airship contact. A contact is distinct from a channel and  represents a "user"
 * within Airship. Contacts may be named and have channels associated with it.
 */
@objc(UAContact)
public class Contact : UAComponent {

    private let dataStore: UAPreferenceDataStore
    private let privacyManager: UAPrivacyManager
    private let channel: UAChannel

    /**
     * Internal only
     * :nodoc:
     */
    @objc
    public init(dataStore: UAPreferenceDataStore,
                config: UARuntimeConfig,
                channel: UAChannel,
                privacyManager: UAPrivacyManager) {
        self.dataStore = dataStore
        self.channel = channel
        self.privacyManager = privacyManager
        super.init(dataStore: dataStore)
    }

    /**
     * Associates the contact with the given named user identifier.
     *
     * @param namedUserID The channel's identifier.
     */
    @objc
    public func identify(_ namedUserID: String) {

    }

    /**
     * Disassociate the channel from its current contact, and create a new
     * un-named contact.
     */
    @objc
    public func reset() {

    }

    /**
     * Edits tags.
     * @returns A tag groups editor.
     */
    @objc
    public func editTags() -> TagGroupsEditor {
        return TagGroupsEditor()
    }

    /**
     * Edits attributes.
     * @returns An attributes editor.
     */
    @objc
    public func editAttibutes() -> AttibutesEditor {
        return AttibutesEditor()
    }

    /**
     * :nodoc:
     */
    public override func onComponentEnableChange() {

    }
}
