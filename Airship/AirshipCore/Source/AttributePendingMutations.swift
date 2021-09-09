/* Copyright Airship and Contributors */

import Foundation

// Legacy attribute mutation. Used for migration to AttributeUpdates.
@objc(UAAttributePendingMutations)
class AttributePendingMutations : NSObject, NSSecureCoding {
    static let codableKey = "com.urbanairship.attributes"

    public static var supportsSecureCoding: Bool = true
    private let mutationsPayload: [[AnyHashable : Any]]
    
    init(mutationsPayload: [[AnyHashable : Any]]) {
        self.mutationsPayload = mutationsPayload
        super.init()
    }
    
    public var attributeUpdates : [AttributeUpdate] {
        get {
            let dateFormatter = Utils.isoDateFormatterUTCWithDelimiter()
            return self.mutationsPayload.compactMap {
                guard let attribute = $0["key"] as? String,
                      let action = $0["action"] as? String,
                      let dateString = $0["timestamp"] as? String else {
                    AirshipLogger.error("Invalid pending attribute \($0)")
                    return nil
                }
                
                guard let date = dateFormatter.date(from: dateString) else {
                    AirshipLogger.error("Unexpected date \(dateString)")
                    return nil
                }
                
                if (action == "set") {
                    guard let value = $0["value"] else {
                        return nil;
                    }
                    return AttributeUpdate(attribute: attribute, type: .set, value: value, date: date)
                } else if (action == "remove") {
                    return AttributeUpdate(attribute: attribute, type: .remove, value: nil, date: date)
                } else {
                    AirshipLogger.error("Unexpected action \(action)")
                    return nil
                }
            }
        }
    }

    func encode(with coder: NSCoder) {
        coder.encode(mutationsPayload as NSArray, forKey: AttributePendingMutations.codableKey)
    }
    
    required init?(coder: NSCoder) {
        self.mutationsPayload = coder.decodeObject(of: NSArray.self, forKey: AttributePendingMutations.codableKey) as? [[AnyHashable : Any]] ?? []
    }
}
