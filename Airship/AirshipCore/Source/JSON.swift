/* Copyright Airship and Contributors */

import Foundation

/// - Note: for internal use only.  :nodoc:
public enum AirshipJSON: Decodable, Equatable {
    case string(String)
    case number(Double)
    case object([String:AirshipJSON])
    case array([AirshipJSON])
    case bool(Bool)
    case null
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let object = try? container.decode([String: AirshipJSON].self) {
            self = .object(object)
        } else if let array = try? container.decode([AirshipJSON].self) {
            self = .array(array)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw AirshipErrors.error("Invalid JSON")
        }
    }
    
    public func unWrap() -> Any? {
        switch (self) {
        case .string(let value):
            return value
        case .number(let value):
            return value
        case .bool(let value):
            return value
        case .null:
            return nil
        case .object(let value):
            var dict: [String: Any] = [:]
            value.forEach {
                dict[$0.key] = $0.value.unWrap()
            }
            return dict
        case .array(let value):
            var array: [Any] = []
            value.forEach {
                if let item = $0.unWrap() {
                    array.append(item)
                }
            }
            return array
        }
       
    }
}
