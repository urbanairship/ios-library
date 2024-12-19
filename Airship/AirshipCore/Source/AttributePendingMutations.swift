/* Copyright Airship and Contributors */

import Foundation

// Legacy attribute mutation. Used for migration to AttributeUpdates.
@objc(UAAttributePendingMutations)
class AttributePendingMutations: NSObject, NSSecureCoding {
    static let codableKey = "com.urbanairship.attributes"

    public static let supportsSecureCoding: Bool = true
    private let mutationsPayload: [[AnyHashable: Any]]

    init(mutationsPayload: [[AnyHashable: Any]]) {
        self.mutationsPayload = mutationsPayload
        super.init()
    }

    public var attributeUpdates: [AttributeUpdate] {

        return self.mutationsPayload.compactMap { update -> (AttributeUpdate?) in
            guard let attribute = update["key"] as? String,
                let action = update["action"] as? String,
                let dateString = update["timestamp"] as? String
            else {
                AirshipLogger.error("Invalid pending attribute \(update)")
                return nil
            }

            guard let date = AirshipDateFormatter.date(fromISOString:  dateString) else {
                AirshipLogger.error("Unexpected date \(dateString)")
                return nil
            }

            if action == "set" {
                guard let valueJSON = update["value"],
                      let value = try? AirshipJSON.wrap(valueJSON)
                else {
                    return nil
                }
                return AttributeUpdate(
                    attribute: attribute,
                    type: .set,
                    jsonValue: value,
                    date: date
                )
            } else if action == "remove" {
                return AttributeUpdate(
                    attribute: attribute,
                    type: .remove,
                    jsonValue: nil,
                    date: date
                )
            } else {
                AirshipLogger.error("Unexpected action \(action)")
                return nil
            }
        }
    }

    func encode(with coder: NSCoder) {
        coder.encode(
            mutationsPayload as NSArray,
            forKey: AttributePendingMutations.codableKey
        )
    }

    required init?(coder: NSCoder) {
        self.mutationsPayload =
            coder.decodeObject(
                of: [
                    NSNull.self, NSNumber.self, NSArray.self, NSDictionary.self,
                    NSString.self,
                ],
                forKey: AttributePendingMutations.codableKey
            ) as? [[AnyHashable: Any]] ?? []
    }
}
