/* Copyright Airship and Contributors */

import Foundation
/**
 * Airship JSON.
 */
public enum AirshipJSON: Codable, Equatable, Sendable, Hashable {
    public static var defaultEncoder: JSONEncoder { return JSONEncoder() }
    public static var defaultDecoder: JSONDecoder { return JSONDecoder() }

    case string(String)
    case number(Double)
    case object([String: AirshipJSON])
    case array([AirshipJSON])
    case bool(Bool)
    case null

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .array(let array): try container.encode(array)
        case .object(let object): try container.encode(object)
        case .number(let number): try container.encode(number)
        case .string(let string): try container.encode(string)
        case .bool(let bool): try container.encode(bool)
        case .null: try container.encodeNil()
        }
    }

    public init(from decoder: any Decoder) throws {
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

    public func unWrap() -> AnyHashable? {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value
        case .bool(let value):
            return value
        case .null:
            return nil
        case .object(let value):
            var dict: [String: AnyHashable] = [:]
            value.forEach {
                dict[$0.key] = $0.value.unWrap()
            }
            return dict
        case .array(let value):
            var array: [AnyHashable] = []
            value.forEach {
                if let item = $0.unWrap() {
                    array.append(item)
                }
            }
            return array
        }
    }

    public static func from(
        json: String?,
        decoder: JSONDecoder = AirshipJSON.defaultDecoder
    ) throws -> AirshipJSON {
        guard let json = json else {
            return .null
        }
        
        guard let data = json.data(using: .utf8) else {
            throw AirshipErrors.error("Invalid encoding: \(json)")
        }
        
        return try decoder.decode(AirshipJSON.self, from: data)
    }
    
    public static func from(
        data: Data?,
        decoder: JSONDecoder = AirshipJSON.defaultDecoder
    ) throws -> AirshipJSON {
        guard let data = data else {
            return .null
        }
        
        return try decoder.decode(AirshipJSON.self, from: data)
    }

    public static func wrap(_ value: Any?, encoder: JSONEncoder = AirshipJSON.defaultEncoder) throws -> AirshipJSON {
        guard let value = value else {
            return .null
        }

        if let json = value as? AirshipJSON {
            return json
        }

        if let string = value as? String {
            return .string(string)
        }

        if let url = value as? URL {
            return .string(url.absoluteString)
        }

        if let date = value as? Date {
            return .string(AirshipDateFormatter.string(fromDate: date, format: .isoDelimitter))
        }

        if let number = value as? NSNumber {
            guard CFBooleanGetTypeID() == CFGetTypeID(number) else {
                return .number(number.doubleValue)
            }
            return .bool(number.boolValue)
        }

        if let bool = value as? Bool {
            return .bool(bool)
        }

        if let number = value as? Double {
            return .number(number)
        }

        if let number = value as? NSNumber {
            return .number(number.doubleValue)
        }

        if let array = value as? [Any?] {
            let mapped: [AirshipJSON] = try array.map { child in
                try wrap(child, encoder: encoder)
            }

            return .array(mapped)
        }

        if let object = value as? [String: Any?] {
            let mapped: [String: AirshipJSON] = try object.mapValues { child in
                try wrap(child, encoder: encoder)
            }

            return .object(mapped)
        }

        if let codable = value as? (any Encodable) {
            return try wrap(
                JSONSerialization.jsonObject(with: try encoder.encode(codable), options: .fragmentsAllowed),
                encoder: encoder
            )
        }

        throw AirshipErrors.error("Invalid JSON \(value)")
    }
    
    public func toData(encoder: JSONEncoder = AirshipJSON.defaultEncoder) throws -> Data {
        return try encoder.encode(self)
    }
    
    public func toString(encoder: JSONEncoder = AirshipJSON.defaultEncoder) throws -> String {
        return String(
            decoding: try encoder.encode(self),
            as: UTF8.self
        )
    }

    public func decode<T: Decodable>(
        decoder: JSONDecoder = AirshipJSON.defaultDecoder,
        encoder: JSONEncoder = AirshipJSON.defaultEncoder
    ) throws -> T {
        let data = try toData(encoder: encoder)
        return try decoder.decode(T.self, from: data)
    }
}

public extension AirshipJSON {
    var isNull: Bool {
        if case .null = self {
            return true
        }
        return false
    }

    var isObject: Bool {
        if case .object(_) = self {
            return true
        }
        return false
    }

    var isArray: Bool {
        if case .array(_) = self {
            return true
        }
        return false
    }

    var isNumber: Bool {
        if case .number(_) = self {
            return true
        }
        return false
    }

    var isString: Bool {
        if case .string(_) = self {
            return true
        }
        return false
    }

    var isBool: Bool {
        if case .bool(_) = self {
            return true
        }
        return false
    }

    var string: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    var object: [String: AirshipJSON]? {
        guard case .object(let value) = self else { return nil }
        return value
    }

    var array: [AirshipJSON]? {
        guard case .array(let value) = self else { return nil }
        return value
    }

    var double: Double? {
        guard case .number(let value) = self else { return nil }
        return value
    }

    var bool: Bool? {
        guard case .bool(let value) = self else { return nil }
        return value
    }

    static func makeObject(builderBlock: (inout AirshipJSONObjectBuilder) -> Void) -> AirshipJSON {
        var builder = AirshipJSONObjectBuilder()
        builderBlock(&builder)
        return builder.build()
    }
}


public struct AirshipJSONObjectBuilder {
    var data: [String: AirshipJSON] = [:]

    public mutating func set(string: String?, key: String) {
        guard let string = string else {
            data[key] = nil
            return
        }
        data[key] = .string(string)
    }

    public mutating func set(array: [AirshipJSON]?, key: String) {
        guard let array = array else {
            data[key] = nil
            return
        }
        data[key] = .array(array)
    }

    public mutating func set(object: [String: AirshipJSON]?, key: String) {
        guard let object = object else {
            data[key] = nil
            return
        }
        data[key] = .object(object)
    }

    public mutating func set(json: AirshipJSON?, key: String) {
        guard let json = json else {
            data[key] = nil
            return
        }
        data[key] = json
    }

    public mutating func set(double: Double?, key: String) {
        guard let double = double else {
            data[key] = nil
            return
        }
        data[key] = .number(double)
    }

    public mutating func set(bool: Bool?, key: String) {
        guard let bool = bool else {
            data[key] = nil
            return
        }
        data[key] = .bool(bool)
    }

    func build() -> AirshipJSON {
        return .object(data)
    }
}
