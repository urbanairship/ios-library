/* Copyright Airship and Contributors */

// NOTE: For internal use only. :nodoc:
@objc(UANSArrayValueTransformer)
public class NSArrayValueTransformer: ValueTransformer {
    
    public override class func transformedValueClass() -> AnyClass {
        return NSData.self
    }
    
    public override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    public override func transformedValue(_ value: Any?) -> Any? {
        guard let value = value else {
            return nil
        }
        
        do {
            return try NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: true)
        } catch {
            AirshipLogger.error("Failed to transform value: \(value), error: \(error)")
            return nil
        }
    }

    public override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let value = value as? Data else {
            return nil
        }
        
        do {
            let classes = [NSString.self, NSDictionary.self, NSArray.self, NSSet.self, NSData.self,
                           NSNumber.self, NSDate.self, NSURL.self, NSUUID.self, NSNull.self]
            return try NSKeyedUnarchiver.unarchivedObject(ofClasses: classes, from: value)
        } catch {
            AirshipLogger.error("Failed to reverse transform value: \(value), error: \(error)")
            return nil
        }
    }
}
