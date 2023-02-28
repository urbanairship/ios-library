/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif


/**
 * Item types.
 */
@objc(UAPreferenceItemType)
public enum ItemType: Int, CustomStringConvertible {
    
    case channelSubscription
    case contactSubscription
    case contactSubscriptionGroup
    case alert
    
    var stringValue: String {
        switch self {
        case .channelSubscription: return "channel_subscription"
        case .contactSubscription: return "contact_subscription"
        case .contactSubscriptionGroup: return "contact_subscription_group"
        case .alert: return "alert"
        }
    }
    
    static func fromString(_ value: String) throws -> ItemType {
        switch value {
        case "channel_subscription": return .channelSubscription
        case "contact_subscription": return .contactSubscription
        case "contact_subscription_group": return .contactSubscriptionGroup
        case "alert": return .alert
        default:
            throw AirshipErrors.error("invalid item \(value)")
        }
    }
    
    public var description: String {
        return stringValue
    }
}

/**
 * Preference section item.
 */
@objc(UAPreferenceItem)
public protocol Item  {
    
    /**
     * The item type string.
     */
    @objc
    var type: String { get }
    
    /**
     * The item type.
     */
    @objc
    var itemType: ItemType { get }
    
    /**
     * The item identifier.
     */
    @objc
    var identifier: String { get }
    
    /**
     * Optional display info.
     */
    @objc
    var display: CommonDisplay? { get }
    
    /**
     * Optional display conditions.
     */
    @objc
    var conditions: [Condition]? { get }
}

/**
 * Channel subscription item.
 */
@objc(UAPreferenceChannelSubscriptionItem)
public class ChannelSubscriptionItem : NSObject, Decodable, Item {
    let typedConditions: [TypedConditions]?

    @objc
    public let type = ItemType.channelSubscription.stringValue
    
    @objc
    public let itemType = ItemType.channelSubscription
    
    @objc
    public let identifier: String
    
    @objc
    public let display: CommonDisplay?

    /**
     * The subcription identifier.
     */
    @objc
    public let subscriptionID: String
    
    @objc
    public lazy var conditions: [Condition]? = {
        self.typedConditions?.map { $0.condition }
    }()
    
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case display = "display"
        case subscriptionID = "subscription_id"
        case typedConditions = "conditions"
    }
}

/**
 * Contact group subscription item.
 */
@objc(UAPreferenceContactSubscriptionGroupItem)
public class ContactSubscriptionGroupItem : NSObject, Decodable, Item {
    
    let typedConditions: [TypedConditions]?

    @objc
    public let type = ItemType.contactSubscriptionGroup.stringValue
    
    @objc
    public let itemType = ItemType.contactSubscriptionGroup
    
    @objc
    public let identifier: String
    
    @objc
    public let display: CommonDisplay?

    /**
     * The subcription identifier.
     */
    @objc
    public let subscriptionID: String
    
    /**
     * Components
     */
    @objc
    public let components: [Component]
    
    @objc
    public lazy var conditions: [Condition]? = {
        self.typedConditions?.map { $0.condition }
    }()
    
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case display = "display"
        case subscriptionID = "subscription_id"
        case typedConditions = "conditions"
        case components = "components"
    }
    
    /**
     * Group component
     */
    @objc(UAPreferenceComponent)
    public class Component : NSObject, Decodable {
        
        /**
         * Scopes
         */
        @objc
        public let scopes: ChannelScopes
    
        /**
         * Display info
         */
        @objc
        public let display: CommonDisplay
        
        enum CodingKeys: String, CodingKey {
            case scopes = "scopes"
            case display = "display"
        }
    }
}

/**
 * Contact subscription item.
 */
@objc(UAPreferenceContactSubscriptionItem)
public class ContactSubscriptionItem : NSObject, Decodable, Item {
    
    let typedConditions: [TypedConditions]?

    @objc
    public let type = ItemType.contactSubscription.stringValue
    
    @objc
    public let itemType = ItemType.contactSubscription
    
    @objc
    public let identifier: String
    
    @objc
    public let display: CommonDisplay?

    /**
     * The subcription identifier.
     */
    @objc
    public let subscriptionID: String
    
    /**
     * Scopes.
     */
    @objc
    public let scopes: ChannelScopes
    
    @objc
    public lazy var conditions: [Condition]? = {
        self.typedConditions?.map { $0.condition }
    }()
    
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case display = "display"
        case subscriptionID = "subscription_id"
        case typedConditions = "conditions"
        case scopes = "scopes"
    }
}


/**
 * Alert item.
 */
@objc(UAPreferenceAlertItem)
public class AlertItem : NSObject, Decodable, Item {
    
    let typedConditions: [TypedConditions]?

    @objc
    public let type = ItemType.alert.stringValue
    
    @objc
    public let itemType = ItemType.alert
    
    @objc
    public let identifier: String
    
    @objc
    public let display: CommonDisplay?

    @objc
    public let button: Button?
    
    @objc
    public lazy var conditions: [Condition]? = {
        self.typedConditions?.map { $0.condition }
    }()
    
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case display = "display"
        case typedConditions = "conditions"
        case button = "button"
    }
    
    /**
     * Alert button
     */
    @objc(UAPreferenceAlertItemButton)
    public class Button : NSObject, Decodable {
        
        let actionJSON : AirshipJSON
        
        /**
         * Button text.
         */
        @objc
        public let text: String
    
        /**
         * Content description.
         */
        @objc
        public let contentDescription: String?
        
        /**
         * Actions payload to run on button tap.
         */
        @objc
        public var actions: Any? {
            return self.actionJSON.unWrap()
        }
        
        enum CodingKeys: String, CodingKey {
            case text = "text"
            case contentDescription = "content_description"
            case actionJSON = "actions"
        }
    }
}

enum TypedItems : Decodable {
    case channelSubscription(ChannelSubscriptionItem)
    case contactSubscription(ContactSubscriptionItem)
    case contactSubscriptionGroup(ContactSubscriptionGroupItem)
    case alert(AlertItem)

    enum CodingKeys: String, CodingKey {
        case type = "type"
    }
    
    var item: Item {
        switch(self) {
        case .channelSubscription(let item): return item
        case .contactSubscription(let item): return item
        case .contactSubscriptionGroup(let item): return item
        case .alert(let item): return item
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try ItemType.fromString(container.decode(String.self, forKey: .type))
        let singleValueContainer = try decoder.singleValueContainer()

        switch type {
        case .channelSubscription:
            self = .channelSubscription((try singleValueContainer.decode(ChannelSubscriptionItem.self)))
        case .contactSubscription:
            self = .contactSubscription((try singleValueContainer.decode(ContactSubscriptionItem.self)))
        case .contactSubscriptionGroup:
            self = .contactSubscriptionGroup((try singleValueContainer.decode(ContactSubscriptionGroupItem.self)))
        case .alert:
            self = .alert((try singleValueContainer.decode(AlertItem.self)))
        }
    }
}
