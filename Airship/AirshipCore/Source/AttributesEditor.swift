/* Copyright Airship and Contributors */

import Foundation

/**
 * Attributes editor.
 */
@objc(UAAttributesEditor)
public class AttributesEditor: NSObject {
    
    private let date : AirshipDate
    private var sets : [String : Any] = [:]
    private var removes : [String] = []
    private let completionHandler : ([AttributeUpdate]) -> Void
    
    init(date: AirshipDate, completionHandler : @escaping ([AttributeUpdate]) -> Void) {
        self.completionHandler = completionHandler
        self.date = date
        super.init()
    }
    
    @objc
    public convenience init(completionHandler : @escaping ([AttributeUpdate]) -> Void) {
        self.init(date: AirshipDate(), completionHandler: completionHandler)
    }
    
    /**
     * Removes an attribute.
     * - Parameters:
     *   - attribute: The attribute.
     */
    @objc(removeAttribute:)
    public func remove(_ attribute: String) {
        guard isValid(key: attribute) else { return }
        sets[attribute] = nil
        removes.append(attribute)
    }

    /**
     * Sets the attribute.
     * - Parameters:
     *   - date: The value
     *   - attribute: The attribute
     */
    @objc(setDate:attribute:)
    public func set(date: Date, attribute: String) {
        add(attribute: attribute, value: Utils.isoDateFormatterUTCWithDelimiter().string(from: date))
    }

    /**
     * Sets the attribute.
     * - Parameters:
     *   - number: The value.
     *   - attribute: The attribute.
     */
    @objc(setNumber:attribute:)
    public func set(number: NSNumber, attribute: String) {
        add(attribute: attribute, value: number)
    }

    /**
     * Sets the attribute.
     * - Parameters:
     *   - string: The value.
     *   - attribute: The attribute.
     */
    @objc(setString:attribute:)
    public func set(string: String, attribute: String) {
        guard string.count >= 1 && string.count <= 1024 else {
            AirshipLogger.error("Invalid attribute value \(string). Must be between 1-1024 characters.")
            return
        }
        
        add(attribute: attribute, value: string)
    }

    /**
     * Sets the attribute.
     * - Parameters:
     *   - float: The value.
     *   - attribute: The attribute.
     */
    public func set(float: Float, attribute: String) {
        add(attribute: attribute, value: float)
    }

    /**
     * Sets the attribute.
     * - Parameters:
     *   - double: The value.
     *   - attribute: The attribute.
     */
    public func set(double: Double, attribute: String) {
        add(attribute: attribute, value: double)
    }

    /**
     * Sets the attribute.
     * - Parameters:
     *   - int: The value.
     *   - attribute: The attribute.
     */
    public func set(int: Int, attribute: String) {
        add(attribute: attribute, value: int)
    }

    /**
     * Sets the attribute.
     * - Parameters:
     *   - uint: The value.
     *   - attribute: The attribute.
     */
    public func set(uint: UInt, attribute: String) {
        add(attribute: attribute, value: uint)
    }
 
    /**
     * Applies the attribute changes.
     */
    @objc
    public func apply() {
        let removeOperations : [AttributeUpdate] = removes.compactMap { AttributeUpdate.remove(attribute: $0, date: self.date.now) }
        let setOperations : [AttributeUpdate] = sets.compactMap { AttributeUpdate.set(attribute: $0.key, value: $0.value, date: self.date.now) }
       
        self.completionHandler(removeOperations + setOperations)
        removes.removeAll()
        sets.removeAll()
    }
    
    private func add(attribute: String, value: Any) {
        guard isValid(key: attribute) else { return }
        sets[attribute] = value
        removes.removeAll(where: { $0 == attribute})
    }
    
    private func isValid(key: String) -> Bool {
        guard key.count >= 1 && key.count <= 1024 else {
            AirshipLogger.error("Invalid attribute key \(key). Must be between 1-1024 characters.")
            return false
        }
        return true
    }
}
