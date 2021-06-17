/* Copyright Airship and Contributors */

import Foundation

/**
 * Attributes editor.
 */
@objc(UAAttibutesEditor)
public class AttibutesEditor: NSObject {

    /**
     * Removes an attribute.
     * @param attribute The attribute.
     */
    @objc(removeAttribute:)
    public func remove(_ attribute: String) {

    }

    /**
     * Sets the attribute.
     * @param date The value.
     * @param attribute The attribute.
     */
    @objc(setDate:attribute:)
    public func set(date: Date, attribute: String) {

    }

    /**
     * Sets the attribute.
     * @param number The value.
     * @param attribute The attribute.
     */
    @objc(setNumber:attribute:)
    public func set(number: NSNumber, attribute: String) {

    }

    /**
     * Sets the attribute.
     * @param string The value.
     * @param attribute The attribute.
     */
    @objc(setString:attribute:)
    public func set(string: String, attribute: String) {

    }

    /**
     * Sets the attribute.
     * @param float The value.
     * @param attribute The attribute.
     */
    public func set(float: Float, attribute: String) {

    }

    /**
     * Sets the attribute.
     * @param double The value.
     * @param attribute The attribute.
     */
    public func set(double: Double, attribute: String) {

    }

    /**
     * Sets the attribute.
     * @param int The value.
     * @param attribute The attribute.
     */
    public func set(int: Int, attribute: String) {

    }

    /**
     * Sets the attribute.
     * @param uint The value.
     * @param attribute The attribute.
     */
    public func set(uint: UInt, attribute: String) {

    }

    /**
     * Applys the attribute changes.
     */
    @objc
    public func apply() {

    }
}
