/* Copyright Airship and Contributors */

import Foundation
import AirshipCore


@objc
public class UAAttributesEditor: NSObject {
    
    var editor: AttributesEditor?
    
    /**
     * Removes an attribute.
     * - Parameters:
     *   - attribute: The attribute.
     */
    @objc(removeAttribute:)
    public func remove(_ attribute: String) {
        self.editor?.remove(attribute)
    }

    /**
     * Sets the attribute.
     * - Parameters:
     *   - date: The value
     *   - attribute: The attribute
     */
    @objc(setDate:attribute:)
    public func set(date: Date, attribute: String) {
        self.editor?.set(date: date, attribute: attribute)
    }

    /**
     * Sets the attribute.
     * - Parameters:
     *   - number: The value.
     *   - attribute: The attribute.
     */
    @objc(setNumber:attribute:)
    public func set(number: NSNumber, attribute: String) {
        self.editor?.set(number: number, attribute: attribute)
    }

    /**
     * Sets the attribute.
     * - Parameters:
     *   - string: The value.
     *   - attribute: The attribute.
     */
    @objc(setString:attribute:)
    public func set(string: String, attribute: String) {
        self.editor?.set(string: string, attribute: attribute)
    }

    /**
     * Applies the attribute changes.
     */
    @objc
    public func apply() {
        self.editor?.apply()
    }
}

