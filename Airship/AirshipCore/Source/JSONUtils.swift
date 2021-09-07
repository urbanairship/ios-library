// Copyright Airship and Contributors

@objc(UAJSONUtils)
public class JSONUtils : NSObject {
    
    @objc(dataWithObject:options:error:)
    public class func data(_ obj: Any, options: JSONSerialization.WritingOptions = []) throws -> Data {
        try validateJSONObject(obj, options: options)
        return try JSONSerialization.data(withJSONObject: obj, options: options)
    }
    
    @objc(stringWithObject:options:error:)
    public class func string(_ obj: Any, options: JSONSerialization.WritingOptions) throws -> String {
        try validateJSONObject(obj, options: options)
        let data = try self.data(obj, options: options)
        guard let string = String(data: data, encoding: .utf8) else {
            throw AirshipErrors.error("Invalid JSON \(obj)")
        }
        
        return string
    }
    
    @objc(stringWithObject:)
    public class func string(_ obj: Any) -> String? {
        return try? self.string(obj, options: [])
    }
    
    @objc(objectWithString:)
    public class func object(_ string: String) -> Any? {
        return try? self.object(string, options: [])
    }
    
    @objc(objectWithString:options:error:)
    public class func object(_ string: String, options: JSONSerialization.ReadingOptions) throws -> Any {
        guard let data = string.data(using: .utf8) else {
            throw AirshipErrors.error("Invalid JSON \(string)")
        }
        
        return try JSONSerialization.jsonObject(with: data, options: options)
    }
    
    private class func validateJSONObject(_ object: Any, options: JSONSerialization.WritingOptions) throws {
        
        var valid = false
        if (options.contains(.fragmentsAllowed)) {
            valid = JSONSerialization.isValidJSONObject([object])
        } else {
            valid = JSONSerialization.isValidJSONObject(object)
        }
        
        guard valid else {
            throw AirshipErrors.error("Invalid JSON: \(object)")
        }
    }
}
