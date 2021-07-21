import Foundation

// NOTE: For internal use only. :nodoc:
enum AttributeUpdateType : String, Codable {
    case remove
    case set
}

// NOTE: For internal use only. :nodoc:
struct AttributeUpdate : Codable {
    let attribute: String
    let type: AttributeUpdateType
    let date: Date
    let jsonValue: JsonValue?
        
    internal init(attribute: String, type: AttributeUpdateType, value: Any?, date : Date) {
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
}
