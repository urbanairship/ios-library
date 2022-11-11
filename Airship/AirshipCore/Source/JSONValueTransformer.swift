/* Copyright Airship and Contributors */

// NOTE: For internal use only. :nodoc:
@objc(UAJSONValueTransformer)
public class JSONValueTransformer: ValueTransformer {

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
            return try JSONUtils.data(
                value,
                options: JSONSerialization.WritingOptions.prettyPrinted
            )
        } catch {
            AirshipLogger.error(
                "Failed to transform value: \(value), error: \(error)"
            )
            return nil
        }
    }

    public override func reverseTransformedValue(_ value: Any?) -> Any? {

        guard let value = value as? Data else {
            return nil
        }

        do {
            return try JSONSerialization.jsonObject(
                with: value,
                options: .mutableContainers
            )
        } catch {
            AirshipLogger.error(
                "Failed to reverse transform value: \(value), error: \(error)"
            )
            return nil
        }
    }
}
