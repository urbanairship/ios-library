/* Copyright Airship and Contributors */

import Foundation

// NOTE: For internal use only. :nodoc:
@objc(UAAttributeUpdateType)
public enum AttributeUpdateType : Int, Codable {
    case remove
    case set
}

// NOTE: For internal use only. :nodoc:
@objc(UAAttributeUpdate)
public class AttributeUpdate : NSObject, Codable {
    @objc
    public let attribute: String
    
    @objc
    public let type: AttributeUpdateType
    
    @objc
    public let date: Date
    let jsonValue: JsonValue?
    
    @objc
    public func value() -> Any? {
        return jsonValue?.value()
    }
    
    @objc
    public init(attribute: String, type: AttributeUpdateType, value: Any?, date : Date) {
        self.attribute = attribute
        self.type = type
        self.jsonValue = JsonValue(value: value)
        self.date = date
    }
    
    static func remove(attribute: String, date : Date = Date()) -> AttributeUpdate {
        return AttributeUpdate(attribute: attribute, type: .remove, value: nil, date: date)
    }
    
    static func set(attribute: String, value: Any, date : Date = Date()) -> AttributeUpdate {
        return AttributeUpdate(attribute: attribute, type: .set, value: value, date: date)
    }
    
    static func == (lhs: AttributeUpdate, rhs: AttributeUpdate) -> Bool {
        return
            lhs.type == rhs.type &&
            lhs.attribute == rhs.attribute &&
            lhs.jsonValue?.jsonEncodedValue == rhs.jsonValue?.jsonEncodedValue
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? AttributeUpdate {
            return self == object
        } else {
            return false
        }
    }
    
    public override var hash : Int {
        var result = 1
        result = 31 * result + self.attribute.hashValue
        result = 31 * result + (self.jsonValue?.jsonEncodedValue?.hashValue ?? 0)
        result = 31 * result + self.type.rawValue
        return result
    }
}
