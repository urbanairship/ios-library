/* Copyright Airship and Contributors */

import Foundation


/**
 * The named user is an alternate method of identifying the device. Once a named
 * user is associated to the device, it can be used to send push notifications
 * to the device.
 */
@available(*, deprecated, message: "Use contact instead.")
@objc
public class UANamedUser : UAComponent {
    
    private let contact : Contact
    
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
    
    @objc
    public init(dataStore: UAPreferenceDataStore, contact: Contact) {
        self.contact = contact
        super.init(dataStore: dataStore)
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
     *  - tags: Array of tags.
     *  - group  Tag group..
     */
    @available(*, deprecated, message: "Use Contact#editTags instead.")
    @objc(addTags:group:)
    public func addTags(_ tags: [String], group: String) {
        let editor = contact.editTags()
        editor.add(tags, group: group)
        editor.apply()
    }
    
    /**
     * Sets tags on the contact.
     * - Parameters:
     *  - tags: Array of tags.
     *  - group  Tag group.
     */
    @available(*, deprecated, message: "Use Contact#editTags instead.")
    @objc(setTags:group:)
    public func setTags(_ tags: [String], group: String) {
        let editor = contact.editTags()
        editor.set(tags, group: group)
        editor.apply()
    }
    
    /**
     * Removes tags on the contact.
     * - Parameters:
     *  - tags: Array of tags.
     *  - group  Tag group.
     */
    @available(*, deprecated, message: "Use Contact#editTags instead.")
    @objc(removeTags:group:)
    public func removeTags(_ tags: [String], group: String) {
        let editor = contact.editTags()
        editor.remove(tags, group: group)
        editor.apply()
    }
    
    /**
     * Applies attribute mutations to the contact.
     *
     * - Parameters:
     *  -  mutations: Attribute mutations.
     */
    @available(*, deprecated, message: "Use Contact#editAttributes instead.")
    @objc(applyAttributeMutations:)
    public func apply(_ mutations: UAAttributeMutations) {
        let editor = contact.editAttibutes()
        
        let pending = UAAttributePendingMutations.init(mutations: mutations, date: UADate())
        
        let attributes = pending.payload()?[UAAttributePayloadKey] as? [[String : Any]]
        attributes?.forEach { attribute in
            if let name = attribute[UAAttributeNameKey] as? String {
                if (UAAttributeSetActionKey == attribute[UAAttributeActionKey] as? String) {
                    if let string = attribute[UAAttributeValueKey] as? String {
                        editor.set(string: string, attribute: name)
                    } else if let number = attribute[UAAttributeValueKey] as? NSNumber {
                        editor.set(number: number, attribute: name)
                    }
                } else {
                    editor.remove(name)
                }
            }
        }
        editor.apply()
    }    
}
