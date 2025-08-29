// Copyright Airship and Contributors

import Foundation

/// - NOTE: Internal use only :nodoc:
public class AirshipJSONUtils: NSObject {

    public class func data(
        _ obj: Any,
        options: JSONSerialization.WritingOptions = []
    ) throws -> Data {
        try validateJSONObject(obj, options: options)
        return try JSONSerialization.data(withJSONObject: obj, options: options)
    }
    
    public class func toData(
        _ obj: Any?
    ) -> Data? {
        guard let obj = obj else {
            return nil
        }
        
        do {
            return try AirshipJSONUtils.data(
                obj,
                options: JSONSerialization.WritingOptions.prettyPrinted
            )
        } catch {
            AirshipLogger.error(
                "Failed to transform value: \(obj), error: \(error)"
            )
            return nil
        }
    }
    
    public class func json(_ data: Data?) -> Any? {
        
        guard let data = data, !data.isEmpty else {
            return nil
        }
        
        do {
            return try JSONSerialization.jsonObject(
                with: data,
                options: .mutableContainers
            )
        } catch {
            AirshipLogger.error("Converting data \(data) failed with error \(error)")
            return nil
        }
        
    }
    

    public class func string(
        _ obj: Any,
        options: JSONSerialization.WritingOptions
    ) throws -> String {
        try validateJSONObject(obj, options: options)
        let data = try self.data(obj, options: options)
        guard let string = String(data: data, encoding: .utf8) else {
            throw AirshipErrors.error("Invalid JSON \(obj)")
        }

        return string
    }

    public class func string(_ obj: Any) -> String? {
        return try? self.string(obj, options: [])
    }

    public class func object(_ string: String) -> Any? {
        return try? self.object(string, options: [])
    }

    public class func object(
        _ string: String,
        options: JSONSerialization.ReadingOptions
    ) throws -> Any {
        guard let data = string.data(using: .utf8) else {
            throw AirshipErrors.error("Invalid JSON \(string)")
        }

        return try JSONSerialization.jsonObject(with: data, options: options)
    }

    public class func decode<T: Decodable>(
        data: Data?
    ) throws -> T {
        guard let data = data else {
            throw AirshipErrors.parseError("data missing response body.")
        }

        return try JSONDecoder()
            .decode(
                T.self,
                from: data
            )
    }

    public class func encode<T: Encodable>(
        object: T?
    ) throws -> Data {
        guard let object = object else {
            throw AirshipErrors.parseError("data missing.")
        }

        return try JSONEncoder().encode(object)
    }

    private class func validateJSONObject(
        _ object: Any,
        options: JSONSerialization.WritingOptions
    ) throws {

        var valid = false
        if options.contains(.fragmentsAllowed) {
            valid = JSONSerialization.isValidJSONObject([object])
        } else {
            valid = JSONSerialization.isValidJSONObject(object)
        }

        guard valid else {
            throw AirshipErrors.error("Invalid JSON: \(object)")
        }
    }
}
