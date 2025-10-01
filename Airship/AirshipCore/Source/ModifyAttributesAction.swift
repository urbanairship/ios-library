/* Copyright Airship and Contributors */

import Foundation

/// Modifies attributes.
///
/// An example JSON payload:
///
/// {
///     "channel": {
///         set: {"key": value, ... },
///         remove: ["attribute", ....]
///     },
///     "named_user": {
///         set: {"key": value, ... },
///         remove: ["attribute", ....]
///     }
/// }
///
///
/// Valid situations: `ActionSituation.foregroundPush`, `ActionSituation.launchedFromPush`
/// `ActionSituation.webViewInvocation`, `ActionSituation.foregroundInteractiveButton`,
/// `ActionSituation.backgroundInteractiveButton`, `ActionSituation.manualInvocation`, and
/// `ActionSituation.automation`
public final class ModifyAttributesAction: AirshipAction {

    /// Default names - "modify_attributes_action", "^a"
    public static let defaultNames = ["modify_attributes_action", "set_attributes_action", "^a"]
    
    /// Default predicate - rejects foreground pushes with visible display options
    public static let defaultPredicate: @Sendable (ActionArguments) -> Bool = { args in
        return args.metadata[ActionArguments.isForegroundPresentationMetadataKey] as? Bool != true
    }
    

    private static let namedUserKey = "named_user"
    private static let channelsKey = "channel"
    private static let setActionKey = "set"
    private static let removeActionKey = "remove"


    private let channel: @Sendable () -> any AirshipChannel
    private let contact: @Sendable () -> any AirshipContact

    init(
        channel: @escaping @Sendable () -> any AirshipChannel,
        contact: @escaping @Sendable () -> any AirshipContact
    ) {
        self.channel = channel
        self.contact = contact
    }

    public convenience init() {
        self.init(
            channel: Airship.componentSupplier(),
            contact: Airship.componentSupplier()
        )
    }
   
    public func accepts(arguments: ActionArguments) async -> Bool {
        guard arguments.situation != .backgroundPush else {
            return false
        }
        
        do {
            let changes = try parse(value: arguments.value)
            return !changes.isEmpty
        } catch {
            return false
        }
    }

    public func perform(arguments: ActionArguments) async throws -> AirshipJSON? {
        let actions = try parse(value: arguments.value)
        
        let channelEditor = channel().editAttributes()
        let contactEditor = contact().editAttributes()
        
        for modification in actions {
            let editor = switch(modification.editor) {
            case .channel: channelEditor
            case .contact: contactEditor
            }
            
            switch(modification) {
            case .set(_, let name, let value):
                switch value {
                case .string(let value):
                    editor.set(string: value, attribute: name)
                case .number(let value):
                    editor.set(number: value, attribute: name)
                case .date(let value):
                    editor.set(date: value, attribute: name)
                case .json(let value):
                    try editor.set(
                        json: value.value,
                        attribute: value.name,
                        instanceID: value.instanceId,
                        expiration: value.expiration
                    )
                    break
                }
                
            case .remove(_, let name):
                editor.remove(name)
            }
        }
        
        let editors: Set<AttributeActionArgs.TargetEditor> = Set(actions.compactMap { $0.editor })
        if editors.contains(.channel) {
            channelEditor.apply()
        }
        
        if editors.contains(.contact) {
            contactEditor.apply()
        }

        return nil
    }
    
    private func parse(value: AirshipJSON) throws -> [AttributeActionArgs] {
        if let unwrapped: [AttributeActionArgs] = try? value.decode() {
            return unwrapped
        }
        
        guard
            let unwrapped = value.unWrap(),
            let dict = unwrapped as? [String: [String: Any]]
        else {
            throw AirshipErrors.error("invalid arguments")
        }
        
        let convertEdits: (AttributeActionArgs.TargetEditor, [String: Any]) throws -> [AttributeActionArgs] = { editor, input in
            let sets: [AttributeActionArgs] = input[ModifyAttributesAction.setActionKey]
                .map { items in
                    guard let items = items as? [String: Any] else {
                        return []
                    }
                    
                    return items
                        .compactMapValues { try? AttributeActionArgs.Value(value: $0) }
                        .map { AttributeActionArgs.set(editor, $0.key, $0.value) }
                }
            ?? []
            
            if input.keys.contains(ModifyAttributesAction.setActionKey) && sets.isEmpty {
                throw AirshipErrors.error("failed to parse set arguments")
            }
            
            let removes: [AttributeActionArgs] = input[ModifyAttributesAction.removeActionKey]
                .map { items in
                    guard let items = items as? [String] else {
                        return []
                    }
                    
                    return items.map { AttributeActionArgs.remove(editor, $0) }
                }
            ?? []
            
            if input.keys.contains(ModifyAttributesAction.removeActionKey) && removes.isEmpty {
                throw AirshipErrors.error("failed to parse remove arguments")
            }
            
            return sets + removes
        }
        
        return (try convertEdits(.contact, dict[ModifyAttributesAction.namedUserKey] ?? [:])) +
               (try convertEdits(.channel, dict[ModifyAttributesAction.channelsKey] ?? [:]))
    }
    
    private enum AttributeActionArgs: Codable, Hashable, Sendable {
        case set(TargetEditor, String, Value)
        case remove(TargetEditor, String)
        
        enum CodingKeys: String, CodingKey {
            case actionType = "action"
            case target = "type"
            case name
            case value
        }
        
        var editor: TargetEditor {
            switch self {
            case .set(let editor, _, _):
                return editor
            case .remove(let editor, _):
                return editor
            }
        }
        
        var name: String {
            switch self {
            case .set(_, let name, _):
                return name
            case .remove(_, let name):
                return name
            }
        }
        
        var value: Value? {
            switch self {
            case .set(_, _, let value):
                return value
            case .remove:
                return nil
            }
        }
        
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let type = try container.decode(ActionType.self, forKey: .actionType)
            
            let editor = try container.decode(TargetEditor.self, forKey: .target)
            let name = try container.decode(String.self, forKey: .name)
            
            switch(type) {
            case .set:
                self = .set(editor, name, try container.decode(Value.self, forKey: .value))
            case .remove:
                self = .remove(editor, name)
            }
        }
        
        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(editor, forKey: .target)
            try container.encode(name, forKey: .name)
            
            switch(self) {
            case .set(_, _, let value):
                try container.encode(ActionType.set, forKey: .actionType)
                try container.encode(value, forKey: .value)
            case .remove(_, _):
                try container.encode(ActionType.remove, forKey: .actionType)
            }
        }
        
        enum ActionType: String, Codable, Sendable {
            case set
            case remove
        }
        
        enum TargetEditor: String, Codable, Sendable {
            case channel
            case contact
        }
        
        enum Value: Codable, Sendable, Hashable {
            case string(String)
            case number(Double)
            case date(Date)
            case json(JsonValue)
            
            init(from decoder: any Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let string = try? container.decode(String.self) {
                    self = .string(string)
                } else if let double = try? container.decode(Double.self) {
                    self = .number(double)
                } else if let date = try? container.decode(Date.self) {
                    self = .date(date)
                } else if let json = try? JsonValue(from: decoder) {
                    self = .json(json)
                } else {
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "unsupported type")
                }
            }
            
            init(value: Any) throws {
                if let string = value as? String {
                    self = .string(string)
                } else if let number = value as? NSNumber {
                    self = .number(number.doubleValue)
                } else if let date = value as? Date {
                    self = .date(date)
                } else {
                    throw AirshipErrors.error("Unsupported value type for attribute modification")
                }
            }
            
            func encode(to encoder: any Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case .string(let string):
                    try container.encode(string)
                case .number(let number):
                    try container.encode(number)
                case .date(let date):
                    try container.encode(date)
                case .json(let json):
                    try container.encode(json)
                }
            }
        }
        
        struct JsonValue: Codable, Sendable, Hashable {
            private static let keyExpiration = "exp"
            
            let name: String
            let instanceId: String
            let expiration: Date?
            let value: [String: AirshipJSON]
            
            init(from decoder: any Decoder) throws {
                let json = try AirshipJSON(from: decoder)
                
                guard
                    case .object(let dict) = json,
                    dict.count == 1,
                    let keyInstanceId = dict.first?.key, keyInstanceId.contains("#"),
                    let contentJson = dict.first?.value,
                    case .object(var content) = contentJson
                else {
                    throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected JSON object but found \(json)"))
                }
                
                let components = keyInstanceId.split(separator: "#")
                guard components.count == 2 else {
                    throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid instance ID format: \(keyInstanceId)"))
                }
                
                self.name = String(components[0])
                self.instanceId = String(components[1])
                self.expiration = Self.convertToDate(content.removeValue(forKey: Self.keyExpiration))
                self.value = content
            }
            
            func encode(to encoder: any Encoder) throws {
                var content = value
                if let expiration {
                    content[Self.keyExpiration] = .number(expiration.timeIntervalSince1970)
                }
                
                let source = [
                    "\(name)#\(instanceId)": content
                ]
                
                try AirshipJSON.wrap(source).encode(to: encoder)
            }
            
            private static func convertToDate(_ value: AirshipJSON?) -> Date? {
                guard let value = value else { return nil }
                
                switch value {
                case .number(let interval):
                    return Date(timeIntervalSince1970: interval)
                default:
                    return nil
                }
            }
        }
    }
}
