/* Copyright Airship and Contributors */

// NOTE: For internal use only. :nodoc:
@objc(UANSURLValueTransformer)
public class NSURLValueTransformer: ValueTransformer {
    
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
            return try NSKeyedUnarchiver.unarchivedObject(ofClass: NSURL.self, from: value)
        } catch {
            AirshipLogger.error("Failed to reverse transform value: \(value), error: \(error)")
            return nil
        }
    }
}
