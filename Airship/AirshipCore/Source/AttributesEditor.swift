/* Copyright Airship and Contributors */

import Foundation

/// Attributes editor.
public final class AttributesEditor {

    private let date: any AirshipDateProtocol
    private var sets: [String: AirshipJSON] = [:]
    private var removes: [String] = []
    private let completionHandler: ([AttributeUpdate]) -> Void

    private static let JSON_EXPIRY_KEY: String = "exp"

    init(
        date: any AirshipDateProtocol,
        completionHandler: @escaping ([AttributeUpdate]) -> Void
    ) {
        self.completionHandler = completionHandler
        self.date = date
    }

    convenience init(
        completionHandler: @escaping ([AttributeUpdate]) -> Void
    ) {
        self.init(date: AirshipDate(), completionHandler: completionHandler)
    }

    /**
     * Removes an attribute.
     * - Parameters:
     *   - attribute: The attribute.
     */
    public func remove(_ attribute: String) {
        tryRemoveAttribute(attribute)
    }

    /**
     * Sets the attribute.
     * - Parameters:
     *   - date: The value
     *   - attribute: The attribute
     */
    public func set(date: Date, attribute: String) {
        trySetAttribute(
            attribute,
            value: .string(
                AirshipDateFormatter.string(fromDate: date, format: .isoDelimitter)
            )
        )
    }

    /**
     * Sets the attribute.
     * - Parameters:
     *   - number: The value.
     *   - attribute: The attribute.
     */
    @available(*, deprecated, message: "Use set(number:number) with Double type instead")
    public func set(number: NSNumber, attribute: String) {
        trySetAttribute(attribute, value: .number(number.doubleValue))
    }
    
    /**
     * Sets the attribute.
     * - Parameters:
     *   - number: The value.
     *   - attribute: The attribute.
     */
    public func set(number: Double, attribute: String) {
        trySetAttribute(attribute, value: .number(number))
    }

    /**
     * Sets the attribute.
     * - Parameters:
     *   - number: The value.
     *   - attribute: The attribute.
     */
    public func set(number: Int, attribute: String) {
        trySetAttribute(attribute, value: .number(Double(number)))
    }

    /**
     * Sets the attribute.
     * - Parameters:
     *   - number: The value.
     *   - attribute: The attribute.
     */
    public func set(number: UInt, attribute: String) {
        trySetAttribute(attribute, value: .number(Double(number)))
    }

    /**
     * Sets the attribute.
     * - Parameters:
     *   - string: The value.
     *   - attribute: The attribute.
     */
    public func set(string: String, attribute: String) {
        guard string.count >= 1 && string.count <= 1024 else {
            AirshipLogger.error(
                "Invalid attribute value \(string). Must be between 1-1024 characters."
            )
            return
        }

        trySetAttribute(attribute, value: .string(string))
    }

    /// Sets a custom attribute with a JSON payload and optional expiration.
    ///
    /// - Parameters:
    ///   - json: A dictionary of key-value pairs (`[String: AirshipJSON]`) representing the custom payload.
    ///   - attribute: The name of the attribute to be set.
    ///   - instanceID: An identifier used to differentiate instances of the attribute.
    ///   - expiration: An optional expiration `Date`. If provided, it must be greater than 0 and less than or equal to 731 days from now.
    ///
    /// - Throws:
    ///   - `AirshipErrors.error` if:
    ///     - The expiration is invalid (more than 731 days or not in the future).
    ///     - The input `json` is empty.
    ///     - The JSON contains a top-level `"exp"` key (reserved for expiration).
    ///     - The attribute contains `"#"`or is empty
    ///     - The instanceID contains `"#"`or is empty
    ///
    public func set(
        json: [String: AirshipJSON],
        attribute: String,
        instanceID: String,
        expiration: Date? = nil
    ) throws {
        if let expiration, expiration.timeIntervalSinceNow > 63158400, expiration.timeIntervalSinceNow <= 0 {
            throw AirshipErrors.error("The expiration is invalid (more than 731 days or not in the future).")
        }

        guard json.isEmpty == false else {
            throw AirshipErrors.error("The input `json` is empty.")
        }

        guard json[Self.JSON_EXPIRY_KEY] == nil else {
            throw AirshipErrors.error("The JSON contains a top-level `\(Self.JSON_EXPIRY_KEY)` key (reserved for expiration).")
        }

        let json = AirshipJSON.makeObject { builder in
            json.forEach { key, value in
                builder.set(json: value, key: key)
            }
            if let expiration {
                builder.set(double: expiration.timeIntervalSince1970, key: Self.JSON_EXPIRY_KEY)
            }
        }

        try setAttribute(attribute, instanceID: instanceID, value: json)
    }

    /// Removes a JSON attribute.
    ///   - attribute: The name of the attribute to be set.
    ///   - instanceID: An identifier used to differentiate instances of the attribute.
    ///
    /// - Throws:
    ///   - `AirshipErrors.error` if:
    ///     - The attribute contains `"#"`or is empty
    ///     - The instanceID contains `"#"`or is empty
    public func remove(attribute: String, instanceID: String) throws {
        try removeAttribute(attribute, instanceID: instanceID)
    }

    /**
     * Sets the attribute.
     * - Parameters:
     *   - float: The value.
     *   - attribute: The attribute.
     */
    public func set(float: Float, attribute: String) {
        trySetAttribute(attribute, value: .number(Double(float)))
    }

    /**
     * Sets the attribute.
     * - Parameters:
     *   - double: The value.
     *   - attribute: The attribute.
     */
    public func set(double: Double, attribute: String) {
        trySetAttribute(attribute, value: .number(double))
    }

    /**
     * Sets the attribute.
     * - Parameters:
     *   - int: The value.
     *   - attribute: The attribute.
     */
    public func set(int: Int, attribute: String) {
        trySetAttribute(attribute, value: .number(Double(int)))
    }

    /**
     * Sets the attribute.
     * - Parameters:
     *   - uint: The value.
     *   - attribute: The attribute.
     */
    public func set(uint: UInt, attribute: String) {
        trySetAttribute(attribute, value: .number(Double(uint)))
    }
    /**
     * Applies the attribute changes.
     */
    public func apply() {
        let removeOperations: [AttributeUpdate] = removes.compactMap {
            AttributeUpdate.remove(attribute: $0, date: self.date.now)
        }
        let setOperations: [AttributeUpdate] = sets.compactMap {
            AttributeUpdate.set(
                attribute: $0.key,
                value: $0.value,
                date: self.date.now
            )
        }

        self.completionHandler(removeOperations + setOperations)
        removes.removeAll()
        sets.removeAll()
    }

    private func setAttribute(_ attribute: String, instanceID: String? = nil, value: AirshipJSON) throws {
        let key = try formatKey(attribute: attribute, instanceID: instanceID)
        sets[key] = value
        removes.removeAll(where: { $0 == key })
    }

    private func removeAttribute(_ attribute: String, instanceID: String? = nil) throws {
        let key = try formatKey(attribute: attribute, instanceID: instanceID)
        sets[key] = nil
        removes.append(key)
    }

    private func trySetAttribute(_ attribute: String, instanceID: String? = nil, value: AirshipJSON) {
        do {
            try setAttribute(attribute, instanceID: instanceID, value: value)
        } catch {
            AirshipLogger.error("Failed to update attribute \(attribute): \(error)")
        }
    }

    private func tryRemoveAttribute(_ attribute: String, instanceID: String? = nil) {
        do {
            try removeAttribute(attribute, instanceID: instanceID)
        } catch {
            AirshipLogger.error("Failed to remove attribute \(attribute): \(error)")
        }
    }

    private func formatKey(attribute: String, instanceID: String? = nil) throws -> String {
        guard
            !attribute.isEmpty,
            !attribute.contains("#")
        else {
            throw AirshipErrors.error(
                "Invalid attribute \(attribute). Must not be empty or contain '#'."
            )
        }

        if let instanceID {
            guard
                !instanceID.isEmpty,
                !instanceID.contains("#")
            else {
                throw AirshipErrors.error(
                    "Invalid instanceID \(instanceID). Must not be empty or contain '#'."
                )
            }
            return "\(attribute)#\(instanceID)"
        } else {
            return attribute
        }
    }
}
