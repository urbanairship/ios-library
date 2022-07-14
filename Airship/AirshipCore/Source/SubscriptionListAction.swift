/* Copyright Airship and Contributors */

import Combine

/**
 * Subscribes to/unsubscribes from a subscription list. This Action is registered under the
 * names ^sla, ^sl, and subscription_list_action.
 *
 * Valid situations: UASituationForegroundPush, UASituationLaunchedFromPush
 * UASituationWebViewInvocation, UASituationForegroundInteractiveButton,
 * UASituationBackgroundInteractiveButton, UASituationManualInvocation, and
 * UASituationAutomation
 *
 * Default predicate: Rejects foreground pushes with visible display options
 *
 * Result value: nil
 *
 * Error: nil
 *
 * Fetch result: UAActionFetchResultNoData
 */
@objc(UASubscriptionListAction)
public class SubscriptionListAction : NSObject, Action {
    @objc
    public static let name = "subscription_list_action"

    @objc
    public static let altName = "edit_subscription_list_action"

    @objc
    public static let shortName = "^sla"

    @objc
    public static let altShortName = "^sl"
    
    private let channel: () -> ChannelProtocol
    private let contact: () -> ContactProtocol
    
    private lazy var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    @objc
    public override convenience init() {
        self.init(channel: Channel.supplier,
                  contact: Contact.supplier)
    }
    
    @objc
    public init(channel: @escaping () -> ChannelProtocol,
                contact: @escaping () -> ContactProtocol) {
        self.channel = channel
        self.contact = contact
    }
    
    public func acceptsArguments(_ arguments: ActionArguments) -> Bool {
        guard arguments.situation != .backgroundPush,
              arguments.value != nil
        else {
            return false
        }

        return true
    }
    
    public func perform(with arguments: ActionArguments, completionHandler: @escaping UAActionCompletionHandler) {
        do {
            let edits = try parse(args: arguments)
            applyChannelEdits(edits)
            applyContactEdits(edits)
            completionHandler(ActionResult.empty())
        } catch {
            completionHandler(ActionResult(error: error))
        }
    }

    private func parse(args: ActionArguments) throws -> [Edit] {
        var edits: Any? = args.value

        if let value = args.value as? [String: Any] {
            edits = value["edits"]
        }

        guard let edits = edits else {
            throw AirshipErrors.error("Invalid argument \(String(describing: args.value))")
        }

        let data = try JSONSerialization.data(withJSONObject: edits, options: [])
        return try self.decoder.decode([Edit].self, from: data)
    }

    private func applyContactEdits(_ edits: [Edit]) {
        let contactEdits = edits.compactMap { (edit: Edit) -> ContactEdit? in
            if case .contact(let contactEdit) = edit {
                return contactEdit
            }
            return nil
        }

        if (!contactEdits.isEmpty) {
            self.contact().editSubscriptionLists { editor in
                contactEdits.forEach { edit in
                    switch (edit.action) {
                    case .subscribe: editor.subscribe(edit.list, scope: edit.scope)
                    case .unsubscribe: editor.unsubscribe(edit.list, scope: edit.scope)
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

        if (!channelEdits.isEmpty) {
            self.channel().editSubscriptionLists { editor in
                channelEdits.forEach { edit in
                    switch (edit.action) {
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

    internal struct ContactEdit : Decodable {
        let list: String
        let action: SubscriptionAction
        let scope: ChannelScope

        enum CodingKeys: String, CodingKey {
            case list = "list"
            case action = "action"
            case scope = "scope"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.list = try container.decode(String.self, forKey: .list)
            self.action = try container.decode(SubscriptionAction.self, forKey: .action)
            self.scope = try ChannelScope.fromString(try container.decode(String.self, forKey: .scope))
        }
    }

    enum Edit: Decodable {
        case channel(ChannelEdit)
        case contact(ContactEdit)

        enum CodingKeys: String, CodingKey {
            case type = "type"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(SubscriptionType.self, forKey: .type)
            let singleValueContainer = try decoder.singleValueContainer()

            switch type {
            case .channel:
                self = .channel((try singleValueContainer.decode(ChannelEdit.self)))
            case .contact:
                self = .contact((try singleValueContainer.decode(ContactEdit.self)))
            }
        }
    }
}
