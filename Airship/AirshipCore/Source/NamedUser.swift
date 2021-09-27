/* Copyright Airship and Contributors */

import Foundation


/**
 * DEPRECATED.  Use contact instead.
 * The named user is an alternate method of identifying the device. Once a named
 * user is associated to the device, it can be used to send push notifications
 * to the device.
 */
@objc(UANamedUser)
public class NamedUser : NSObject, Component {
    
    private let contact : ContactProtocol
    
    /**
     * The named user ID for this device.
     */
    @available(*, deprecated, message: "Use Contact#identify or Contact#reset instead.")
    @objc
    public var identifier : String? {
        get {
            return contact.namedUserID
        }
        set {
            if let value = newValue {
                contact.identify(value)
            } else {
                contact.reset()
            }
        }
    }
    
    
    private let disableHelper: ComponentDisableHelper
        
    // NOTE: For internal use only. :nodoc:
    public var isComponentEnabled: Bool {
        get {
            return disableHelper.enabled
        }
        set {
            disableHelper.enabled = newValue
        }
    }
    
    /// The shared  named user  instance.
    @objc
    @available(*, deprecated, message: "Use contact instead.")
    public static var shared: NamedUser! {
        return Airship.namedUser
    }

    @objc
    public init(dataStore: PreferenceDataStore, contact: ContactProtocol) {
        self.contact = contact
        self.disableHelper = ComponentDisableHelper(dataStore: dataStore,
                                                    className: "UANamedUser")

        super.init()
    }
    
    /**
     * Force updating the association or disassociation of the current named user ID.
     */
    @available(*, deprecated, message: "No longer required.")
    @objc
    public func forceUpdate() {
        // no-op
    }
    
    
    @available(*, deprecated, message: "No longer required.")
    @objc
    public func updateTags() {
        // no-op
    }
    
    /**
     * Add tags on the contact.
     * - Parameters:
     *   - tags: Array of tags.
     *   - group  Tag group..
     */
    @available(*, deprecated, message: "Use Contact#editTagGroups instead.")
    @objc(addTags:group:)
    public func addTags(_ tags: [String], group: String) {
        let editor = contact.editTagGroups()
        editor.add(tags, group: group)
        editor.apply()
    }
    
    /**
     * Sets tags on the contact.
     * - Parameters:
     *   - tags: Array of tags.
     *   - group  Tag group.
     */
    @available(*, deprecated, message: "Use Contact#editTagGroups instead.")
    @objc(setTags:group:)
    public func setTags(_ tags: [String], group: String) {
        let editor = contact.editTagGroups()
        editor.set(tags, group: group)
        editor.apply()
    }
    
    /**
     * Removes tags on the contact.
     * - Parameters:
     *   - tags: Array of tags.
     *   - group  Tag group.
     */
    @available(*, deprecated, message: "Use Contact#editTagGroups instead.")
    @objc(removeTags:group:)
    public func removeTags(_ tags: [String], group: String) {
        let editor = contact.editTagGroups()
        editor.remove(tags, group: group)
        editor.apply()
    }
    
    /**
     * Applies attribute mutations to the contact.
     *
     * - Parameters:
     *   -  mutations: Attribute mutations.
     */
    @available(*, deprecated, message: "Use Contact#editAttributes instead.")
    @objc(applyAttributeMutations:)
    public func apply(_ mutations: AttributeMutations) {
        let editor = contact.editAttributes()
        mutations.applyMutations(editor: editor)
        editor.apply()
    }    
}
