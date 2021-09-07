// Copyright Airship and Contributors

@objc(UAJSONSerialization)
public class UAJSONSerialization : NSObject {
    
    /**
     * Wrapper around JSONSerialization's dataWithJSONObject:options: that checks if the JSON object is
     * serializable prior to attempting to serialize. This is to avoid crashing when serialization is attempted
     * on an invalid JSON object.
     *
     * - Parameters:
     *  - obj: JSON object to serialize into data.
     *  - options: WritingOptions for serialization.
     * - Returns: The serialized data if JSON object is valid, otherwise nil.
     */
    @objc(dataWithJSONObject:options:error:)
    public class func data(_ obj: Any, options: JSONSerialization.WritingOptions = []) throws -> Data {
        do {
            return try JSONSerialization.data(withJSONObject: obj, options: options)
        } catch _ {
            AirshipLogger.error("Attempted to serialize an invalid JSON object: \(obj)")
            throw AirshipErrors.parseError("Attempted to serialize an invalid JSON object: \(obj)")
        }
    }
}
