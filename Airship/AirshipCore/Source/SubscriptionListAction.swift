/* Copyright Airship and Contributors */

import Foundation

/// Subscribes to/unsubscribes from a subscription list.
///
/// Valid situations: `ActionSituation.foregroundPush`, `ActionSituation.launchedFromPush`
/// `ActionSituation.webViewInvocation`, `ActionSituation.foregroundInteractiveButton`,
/// `ActionSituation.backgroundInteractiveButton`, `ActionSituation.manualInvocation`, and
/// `ActionSituation.automation`
public final class SubscriptionListAction: AirshipAction {

    /// Default names - "subscription_list_action", "^sl", "edit_subscription_list_action", "^sla"
    public static let defaultNames: [String] = [
        "subscription_list_action", "^sl", "edit_subscription_list_action", "^sla"
    ]
    
    /// Default predicate - rejects foreground pushes with visible display options
    public static let defaultPredicate: @Sendable (ActionArguments) -> Bool = { args in
        return args.metadata[ActionArguments.isForegroundPresentationMetadataKey] as? Bool != true
    }

    private let channel: @Sendable () -> any AirshipChannel
    private let contact: @Sendable () -> any AirshipContact
  
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
    
    public var _decoder: JSONDecoder {
        return decoder
    }

    public convenience init() {
        self.init(
            channel: Airship.componentSupplier(),
            contact: Airship.componentSupplier()
        )
    }


    init(
        channel: @escaping @Sendable () -> any AirshipChannel,
        contact: @escaping @Sendable () -> any AirshipContact
    ) {
        self.channel = channel
        self.contact = contact
    }

    public func accepts(arguments: ActionArguments) async -> Bool {
        guard arguments.situation != .backgroundPush
        else {
            return false
        }

        return true
    }

    public func perform(arguments: ActionArguments) async throws -> AirshipJSON? {
        
        let edits = try parse(args: arguments)
        applyChannelEdits(edits)
        applyContactEdits(edits)
        return arguments.value
        
    }

    private func parse(args: ActionArguments) throws -> [Edit] {
        var edits: Any? = args.value.unWrap()

        let unwrapped = args.value.unWrap()
        if let value = unwrapped as? [String: Any] {
            edits = value["edits"]
        }

        guard let edits = edits else {
            throw AirshipErrors.error(
                "Invalid argument \(String(describing: args.value))"
            )
        }

        let data = try JSONSerialization.data(
            withJSONObject: edits,
            options: []
        )
        return try self.decoder.decode([Edit].self, from: data)
    }

    private func applyContactEdits(_ edits: [Edit]) {
        let contactEdits = edits.compactMap { (edit: Edit) -> ContactEdit? in
            if case .contact(let contactEdit) = edit {
                return contactEdit
            }
            return nil
        }

        if !contactEdits.isEmpty {
            self.contact()
                .editSubscriptionLists { editor in
                    contactEdits.forEach { edit in
                        switch edit.action {
                        case .subscribe:
                            editor.subscribe(edit.list, scope: edit.scope)
                        case .unsubscribe:
                            editor.unsubscribe(edit.list, scope: edit.scope)
                        }
                    }
                }
        }
    }

    private func applyChannelEdits(_ edits: [Edit]) {
        let channelEdits = edits.compactMap { (edit: Edit) -> ChannelEdit? in
            if case .channel(let channelEdit) = edit {
                return channelEdit
            }
            return nil
        }

        if !channelEdits.isEmpty {
            self.channel()
                .editSubscriptionLists { editor in
                    channelEdits.forEach { edit in
                        switch edit.action {
                        case .subscribe: editor.subscribe(edit.list)
                        case .unsubscribe: editor.unsubscribe(edit.list)
                        }
                    }
                }
        }
    }

    internal enum SubscriptionAction: String, Decodable {
        case subscribe
        case unsubscribe
    }

    internal enum SubscriptionType: String, Decodable {
        case channel
        case contact
    }

    internal struct ChannelEdit: Decodable {
        let list: String
        let action: SubscriptionAction

        enum CodingKeys: String, CodingKey {
            case list = "list"
            case action = "action"
        }
    }

    internal struct ContactEdit: Decodable {
        let list: String
        let action: SubscriptionAction
        let scope: ChannelScope

        enum CodingKeys: String, CodingKey {
            case list = "list"
            case action = "action"
            case scope = "scope"
        }
    }

    enum Edit: Decodable {
        case channel(ChannelEdit)
        case contact(ContactEdit)

        enum CodingKeys: String, CodingKey {
            case type = "type"
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(
                SubscriptionType.self,
                forKey: .type
            )
            let singleValueContainer = try decoder.singleValueContainer()

            switch type {
            case .channel:
                self = .channel(
                    (try singleValueContainer.decode(ChannelEdit.self))
                )
            case .contact:
                self = .contact(
                    (try singleValueContainer.decode(ContactEdit.self))
                )
            }
        }
    }
}
