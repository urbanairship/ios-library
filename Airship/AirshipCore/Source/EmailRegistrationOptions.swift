/* Copyright Airship and Contributors */

import Foundation

/**
 * Email registration options
 */
@objc(UAEmailRegistrationOptions)
public class EmailRegistrationOptions : NSObject, Codable {
    
    /**
     * Transactional opted-in value
     */
    let transactionalOptedIn: Date?
    
    /**
     * Commercial opted-in value
     */
    let commercialOptedIn: Date?
    
    /**
     * Properties
     */
    let properties: JsonValue?
    
    /**
     * Double opt-in value
     */
    let doubleOptIn: Bool
    
    private init(transactionalOptedIn: Date?, commercialOptedIn: Date? = nil, properties: [String: Any]?, doubleOptIn: Bool = false) {
        self.transactionalOptedIn = transactionalOptedIn
        self.commercialOptedIn = commercialOptedIn
        self.properties = JsonValue(value: properties)
        self.doubleOptIn = doubleOptIn
    }
    
    /// Returns an Email registration options with double opt-in value to false
    /// - Parameter transactionalOptedIn: The transactional opted-in value
    /// - Parameter commercialOptedIn: The commercial opted-in value
    /// - Parameter properties: The properties. They must be JSON serializable.
    /// - Returns: An Email registration options.
    @objc
    public static func commercialOptions(transactionalOptedIn: Date?,
                                         commercialOptedIn: Date?,
                                         properties: [String: Any]?) -> EmailRegistrationOptions {
        return EmailRegistrationOptions(transactionalOptedIn: transactionalOptedIn,
                                        commercialOptedIn: commercialOptedIn,
                                        properties: properties)
    }
    
    /// Returns an Email registration options.
    /// - Parameter transactionalOptedIn: The transactional opted-in date.
    /// - Parameter properties: The properties. They must be JSON serializable.
    /// - Parameter doubleOptIn: The double opt-in value
    /// - Returns: An Email registration options.
    @objc
    public static func options(transactionalOptedIn: Date?, properties: [String: Any]?, doubleOptIn: Bool) -> EmailRegistrationOptions {
        return EmailRegistrationOptions(transactionalOptedIn: transactionalOptedIn,
                                        properties: properties,
                                        doubleOptIn: doubleOptIn)
    }
    
    /// Returns an Email registration options.
    /// - Parameter properties: The properties. They must be JSON serializable.
    /// - Parameter doubleOptIn: The double opt-in value
    /// - Returns: An Email registration options.
    @objc
    public static func options(properties: [String: Any]?, doubleOptIn: Bool) -> EmailRegistrationOptions {
        return EmailRegistrationOptions(transactionalOptedIn: nil,
                                        properties: properties,
                                        doubleOptIn: doubleOptIn)
    }
}
