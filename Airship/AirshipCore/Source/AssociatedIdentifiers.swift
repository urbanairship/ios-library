/* Copyright Airship and Contributors */

/**
 * Defines analytics identifiers to be associated with
 * the device.
 */
@objc(UAAssociatedIdentifiers)
public class AssociatedIdentifiers : NSObject{

    /**
     * Maximum number of associated IDs that can be set.
     */
    @objc
    public static let maxCount = 100

    /**
     * Character limit for associated IDs or keys.
     */
    @objc
    public static let maxCharacterCount = 255


    /**
     * The advertising ID.
     */
    @objc
    public var advertisingID: String? {
        get {
            return self.identifiers["com.urbanairship.idfa"]
        }
        set {
            self.identifiers["com.urbanairship.idfa"] = newValue
        }
    }

    /**
     * The application's vendor ID.
     */
    @objc
    public var vendorID: String? {
        get {
            return self.identifiers["com.urbanairship.vendor"]
        }
        set {
            self.identifiers["com.urbanairship.vendor"] = newValue
        }
    }

    /**
     * Indicates whether the user has limited ad tracking.
     */
    @objc
    public var advertisingTrackingEnabled: Bool {
        get {
            return self.identifiers["com.urbanairship.limited_ad_tracking_enabled"] == "false"
        }
        set {
            self.identifiers["com.urbanairship.limited_ad_tracking_enabled"] = newValue ? "false" : "true"
        }
    }

    /**
     * A map of all the associated identifiers.
     */
    @objc
    public var allIDs : [String : String] {
        get {
            return identifiers;
        }
    }

    private var identifiers : [String : String]

    @objc
    public init(identifiers: [String : String]?) {
        self.identifiers = identifiers ?? [:]
        super.init()
    }

    @objc
    public convenience init(dictionary: [String : String]?) {
        self.init(identifiers: dictionary)
    }

    @objc
    public override convenience init() {
        self.init(identifiers: nil)
    }

    /**
     * Factory method to create an empty identifiers object.
     * - Returns: The created associated identifiers.
     */
    @objc
    public class func identifiers() -> AssociatedIdentifiers {
        return AssociatedIdentifiers()
    }

    /**
     * Factory method to create an associated identifiers instance with a dictionary
     * of custom identifiers (containing strings only).
     * - Returns: The created associated identifiers.
     */
    @objc(identifiersWithDictionary:)
    public class func identifiers(identifiers: [String : String]?) -> AssociatedIdentifiers {
        return AssociatedIdentifiers(identifiers: identifiers)
    }

    /**
     * Sets an identifier mapping.
     * - Parameter identifier: The value of the identifier, or `nil` to remove the identifier.
     * @parm key The key for the identifier
     */
    @objc(setIdentifier:forKey:)
    public func set(identifier: String?, key: String) {
        self.identifiers[key] = identifier
    }
}
