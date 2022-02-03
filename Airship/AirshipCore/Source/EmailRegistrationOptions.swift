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
    let transactionalOptedIn: Bool
    
    /**
     * Commercial opted-in value
     */
    let commercialOptedIn: Bool
    
    /**
     * Properties
     */
    let properties: JsonValue?
    
    /**
     * Double opt-in value
     */
    let doubleOptIn: Bool
    
    private init(transactionalOptedIn: Bool, commercialOptedIn: Bool, properties: Any?, doubleOptIn: Bool) {
        self.transactionalOptedIn = transactionalOptedIn
        self.commercialOptedIn = commercialOptedIn
        self.properties = JsonValue(value: properties)
        self.doubleOptIn = doubleOptIn
    }
    
    /// Returns an Email registration options with double opt-in value to false
    /// - Parameter transactionalOptedIn: The transactional opted-in value
    /// - Parameter commercialOptedIn: The commercial opted-in value
    /// - Parameter properties: The properties
    /// - Returns: An Email registration options.
    @objc
    public static func commercialOptIn(transactionalOptedIn: Bool, commercialOptedIn: Bool, properties: Any?) -> EmailRegistrationOptions {
        return EmailRegistrationOptions(transactionalOptedIn: transactionalOptedIn, commercialOptedIn: commercialOptedIn, properties: properties, doubleOptIn: false)
    }
    
    /// Returns an Email registration options with commercial opted-in value to false
    /// - Parameter transactionalOptedIn: The transactional opted-in value
    /// - Parameter properties: The properties
    /// - Parameter doubleOptIn: The double opt-in value
    /// - Returns: An Email registration options.
    @objc
    public static func optIn(transactionalOptedIn: Bool, properties: Any?, doubleOptIn: Bool) -> EmailRegistrationOptions {
        return EmailRegistrationOptions(transactionalOptedIn: transactionalOptedIn, commercialOptedIn: false, properties: properties, doubleOptIn: doubleOptIn)
    }
}
