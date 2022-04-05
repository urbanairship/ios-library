/* Copyright Airship and Contributors */

import Combine

/**
 * Subscribes to/unsubscribes from a subscription list. This Action is registered under the
 * names ^sla and "subscription_list_action".
 *
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
    public static let shortName = "^sla"
    
    private let channel: () -> ChannelProtocol
    private let contact: () -> ContactProtocol
    
    private lazy var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    internal struct SubscriptionListPayload : Decodable {
        let subscriptionEdits: [SubscriptionEdit]
        
        enum CodingKeys: String, CodingKey {
            case subscriptionEdits = "edits"
        }
        
        enum SubscriptionEdit : Decodable {
            case channel(ChannelSubscriptionEdit)
            case contact(ContactSubscriptionEdit)

            enum CodingKeys: String, CodingKey {
                case type = "type"
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let type = try container.decode(SubscriptionEditType.self, forKey: .type)
                let singleValueContainer = try decoder.singleValueContainer()

                switch type {
                case .channel:
                    self = .channel((try singleValueContainer.decode(ChannelSubscriptionEdit.self)))
                case .contact:
                    self = .contact((try singleValueContainer.decode(ContactSubscriptionEdit.self)))
                }
            }
        }
        
        enum SubscriptionEditType : String, Decodable, Equatable {
            case channel
            case contact
        }
        
        struct ChannelSubscriptionEdit : Decodable {
            let type = "channel"
            let list: String
            let action: SubscriptionListActionType
            
            enum CodingKeys: String, CodingKey {
                case list = "list"
                case action = "action"
            }
        }
        
        struct ContactSubscriptionEdit : Decodable {
            let type = "contact"
            let list: String
            let action: SubscriptionListActionType
            let scope: ChannelScope
            
            enum CodingKeys: String, CodingKey {
                case list = "list"
                case action = "action"
                case scope = "scope"
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.list = try container.decode(String.self, forKey: .list)
                self.action = try container.decode(SubscriptionListActionType.self, forKey: .action)
                self.scope = try ChannelScope.fromString(try container.decode(String.self, forKey: .scope))
            }
        }
    }
    
    enum SubscriptionListActionType : String, Decodable, Equatable {
        case subscribe = "subscribe"
        case unsubcribe = "unsubscribe"
    }
    
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
        guard arguments.situation != .backgroundPush else {
            return false
        }
        
        if arguments.value is [[String:String]] {
            return true
        }
       
        return false
    }
    
    public func perform(with arguments: ActionArguments, completionHandler: @escaping UAActionCompletionHandler) {
        guard let arg = arguments.value else {
            completionHandler(ActionResult.empty())
            return
        }
        
        let channel = self.channel()
        let contact = self.contact()
        var payload: SubscriptionListPayload? = nil
        
        do {
            let data = try JSONSerialization.data(withJSONObject: arg, options: [])
            payload = try self.decoder.decode(SubscriptionListPayload.self,
                                               from: data)
        }
        catch {
            AirshipLogger.error("Invalid subscription list actions payload: \(String(describing: payload))")
            let error = AirshipErrors.error("Invalid subscription list actions payload")
            completionHandler(ActionResult(error: error))
            return
        }
        
        let channelEditor = channel.editSubscriptionLists()
        let contactEditor = contact.editSubscriptionLists()
        
        payload?.subscriptionEdits.forEach { edit in
            switch (edit) {
            case .channel(let channelEdit):
                if channelEdit.action == .subscribe {
                    channelEditor.subscribe(channelEdit.list)
                } else if channelEdit.action == .unsubcribe {
                    channelEditor.unsubscribe(channelEdit.list)
                }
            case .contact(let contactEdit):
                if contactEdit.action == .subscribe {
                    contactEditor.subscribe(contactEdit.list, scope: contactEdit.scope)
                } else if contactEdit.action == .unsubcribe {
                    contactEditor.unsubscribe(contactEdit.list, scope: contactEdit.scope)
                }
            }
        }
       
        completionHandler(ActionResult.empty())
        
        channelEditor.apply()
        contactEditor.apply()
    }
}
