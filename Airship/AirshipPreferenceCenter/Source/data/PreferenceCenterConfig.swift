/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Preference center config.
@objc(UAPreferenceCenterConfig)
public class PreferenceCenterConfig: NSObject, Decodable {

    /// The config's identifier.
    @objc
    public let identifier: String

    /// The config's sections.
    public let sections: [Section]

    @objc(sections)
    public var _sections: [PreferenceCenterConfigSection] {
        self.sections.map { $0.info }
    }


    /// The config's display info.
    @objc
    public let display: CommonDisplay?

    /**
     * The config's options.
     */
    @objc
    public let options: Options?


    public init(identifier: String,
                sections: [Section],
                display: CommonDisplay? = nil,
                options: Options? = nil) {

        self.identifier = identifier
        self.sections = sections
        self.display = display
        self.options = options
    }

    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case sections = "sections"
        case display = "display"
        case options = "options"
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? PreferenceCenterConfig else {
            return false
        }

        return self.identifier == object.identifier
        && self.sections == object.sections
        && self.display == object.display
        && self.options == object.options
    }

    /// Config options.
    @objc(UAPreferenceCenterConfigOptions)
    public class Options: NSObject, Decodable {

        /**
         * The config identifier.
         */
        @objc
        public let mergeChannelDataToContact: Bool

        enum CodingKeys: String, CodingKey {
            case mergeChannelDataToContact = "merge_channel_data_to_contact"
        }

        @objc
        public init(mergeChannelDataToContact: Bool) {
            self.mergeChannelDataToContact = mergeChannelDataToContact
        }

        public required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            if let mergeChannelDataToContact = try? container.decode(Bool.self, forKey: .mergeChannelDataToContact) {
                self.mergeChannelDataToContact = mergeChannelDataToContact
            } else {
                self.mergeChannelDataToContact = false
            }
        }

        public override func isEqual(_ object: Any?) -> Bool {
            guard let object = object as? Options else {
                return false
            }

            return self.mergeChannelDataToContact == object.mergeChannelDataToContact
        }
    }

    /// Common display info
    @objc(UAPreferenceConfigCommonDisplay)
    public class CommonDisplay : NSObject, Decodable {

        /// Title
        @objc
        public let title: String?

        // Subtitle
        @objc
        public let subtitle: String?

        public init(title: String? = nil, subtitle: String? = nil) {
            self.title = title
            self.subtitle = subtitle
        }

        enum CodingKeys: String, CodingKey {
            case title = "name"
            case subtitle = "description"
        }

        public override func isEqual(_ object: Any?) -> Bool {
            guard let object = object as? CommonDisplay else {
                return false
            }

            return self.title == object.title && self.subtitle == object.subtitle
        }
    }

    @objc(UAPreferenceCenterConfigNotificationOptInCondition)
    public class NotificationOptInCondition: NSObject, Decodable, PreferenceConfigCondition {

        @objc(UANotificationOptInConditionStatus)
        public enum OptInStatus: Int, Equatable {
            case optedIn
            case optedOut
        }

        @objc
        public let type = PreferenceCenterConfigConditionType.notificationOptIn

        @objc
        public let optInStatus: OptInStatus

        enum CodingKeys: String, CodingKey {
            case optInStatus = "when_status"
        }

        public init(optInStatus: OptInStatus) {
            self.optInStatus = optInStatus
        }

        public required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let optInStatus = try container.decode(String.self, forKey: .optInStatus)

            switch optInStatus {
            case "opt_in":
                self.optInStatus = .optedIn
            case "opt_out":
                self.optInStatus = .optedOut
            default:
                throw AirshipErrors.error("Invalid status \(optInStatus)")
            }
        }

        public override func isEqual(_ object: Any?) -> Bool {
            guard let object = object as? NotificationOptInCondition else {
                return false
            }

            return self.optInStatus == object.optInStatus
        }
    }


    /**
     * Typed conditions.
     */
    public enum Condition: Decodable, Equatable {
        case notificationOptIn(NotificationOptInCondition)

        enum CodingKeys: String, CodingKey {
            case type = "type"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try PreferenceCenterConfigConditionType.fromString(container.decode(String.self, forKey: .type))
            let singleValueContainer = try decoder.singleValueContainer()

            switch type {
            case .notificationOptIn:
                self = .notificationOptIn(try singleValueContainer.decode(NotificationOptInCondition.self))
            }
        }
    }



    /// Common section.
    @objc(UAPreferenceCenterConfigCommonSection)
    public class CommonSection: NSObject, Decodable, PreferenceCenterConfigSection {

        /// The section's type.
        @objc
        public let type = PreferenceCenterConfigSectionType.common

        /// The section's identifier.
        @objc
        public let identifier: String

        /// The section's items.
        public let items: [Item]

        @objc(items)
        public var _items: [PreferenceCenterConfigItem] {
            return self.items.map { $0.info }
        }

        /// The section's display info.
        @objc
        public let display: CommonDisplay?

        /// The section's display conditions.
        public let conditions: [Condition]?

        @objc(conditions)
        public var _conditions: [PreferenceConfigCondition]? {
            self.conditions?.map { $0.info }
        }


        public init(identifier: String,
                    items: [Item],
                    display: CommonDisplay? = nil,
                    conditions: [Condition]? = nil) {

            self.identifier = identifier
            self.items = items
            self.display = display
            self.conditions = conditions
        }

        enum CodingKeys: String, CodingKey {
            case identifier = "id"
            case display = "display"
            case items = "items"
            case conditions = "conditions"
        }

        public override func isEqual(_ object: Any?) -> Bool {
            guard let object = object as? CommonSection else {
                return false
            }

            return self.identifier == object.identifier
            && self.display == object.display
            && self.items == object.items
            && self.conditions == object.conditions
        }
    }

    /// Labeled section break info.
    @objc(UAPreferenceLabeledSectionBreak)
    public class LabeledSectionBreak: NSObject, Decodable,
                                      PreferenceCenterConfigSection {

        /// The section's type.
        @objc
        public let type = PreferenceCenterConfigSectionType.labeledSectionBreak

        /// The section's identifier.
        @objc
        public let identifier: String

        /// The section's display info.
        @objc
        public let display: CommonDisplay?

        /// The section's display conditions.
        public let conditions: [Condition]?

        @objc(conditions)
        public var _conditions: [PreferenceConfigCondition]? {
            self.conditions?.map { $0.info }
        }

        public init(identifier: String,
                    display: CommonDisplay? = nil,
                    conditions: [Condition]? = nil) {

            self.identifier = identifier
            self.display = display
            self.conditions = conditions
        }

        enum CodingKeys: String, CodingKey {
            case identifier = "id"
            case display = "display"
            case conditions = "conditions"
        }

        public override func isEqual(_ object: Any?) -> Bool {
            guard let object = object as? LabeledSectionBreak else {
                return false
            }

            return self.identifier == object.identifier
            && self.display == object.display
            && self.conditions == object.conditions
        }
    }

    /// Preference config section.
    public enum Section: Decodable, Equatable {

        /// Common section
        case common(CommonSection)

        /// Labeled section break
        case labeledSectionBreak(LabeledSectionBreak)

        enum CodingKeys: String, CodingKey {
            case type = "type"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try PreferenceCenterConfigSectionType.fromString(container.decode(String.self, forKey: .type))
            let singleValueContainer = try decoder.singleValueContainer()

            switch type {
            case .common:
                self = .common((try singleValueContainer.decode(CommonSection.self)))
            case .labeledSectionBreak:
                self = .labeledSectionBreak((try singleValueContainer.decode(LabeledSectionBreak.self)))
            }
        }
    }
    /// Channel subscription item info.
    @objc(UAPreferenceCenterConfigChannelSubscription)
    public class ChannelSubscription: NSObject, Decodable, PreferenceCenterConfigItem {

        /// The item's type.
        @objc
        public let type = PreferenceCenterConfigItemType.channelSubscription

        /// The item's identifier.
        @objc
        public let identifier: String

        /// The item's subscription ID.
        @objc
        public let subscriptionID: String

        /// The item's display info.
        @objc
        public let display: CommonDisplay?

        /// The item's display conditions.
        public let conditions: [Condition]?

        @objc(conditions)
        public var _conditions: [PreferenceConfigCondition]? {
            self.conditions?.map { $0.info }
        }

        enum CodingKeys: String, CodingKey {
            case identifier = "id"
            case display = "display"
            case subscriptionID = "subscription_id"
            case conditions = "conditions"
        }

        public init(identifier: String,
                    subscriptionID: String,
                    display: CommonDisplay? = nil,
                    conditions: [Condition]? = nil) {

            self.identifier = identifier
            self.subscriptionID = subscriptionID
            self.display = display
            self.conditions = conditions
        }

        public override func isEqual(_ object: Any?) -> Bool {
            guard let object = object as? ChannelSubscription else {
                return false
            }

            return self.identifier == object.identifier
            && self.display == object.display
            && self.subscriptionID == object.subscriptionID
            && self.conditions == object.conditions
        }
    }

    /// Group contact subscription item info.
    @objc(UAPreferenceCenterConfigContactSubscriptionGroup)
    public class ContactSubscriptionGroup: NSObject, Decodable, PreferenceCenterConfigItem {

        /// The item's type.
        @objc
        public let type = PreferenceCenterConfigItemType.contactSubscriptionGroup

        /// The item's identifier.
        @objc
        public let identifier: String

        /// The item's subscription ID.
        @objc
        public let subscriptionID: String

        /// Components
        @objc
        public let components: [Component]

        /// The item's display info.
        @objc
        public let display: CommonDisplay?

        /// The item's display conditions.
        public let conditions: [Condition]?

        @objc(conditions)
        public var _conditions: [PreferenceConfigCondition]? {
            self.conditions?.map { $0.info }
        }

        enum CodingKeys: String, CodingKey {
            case identifier = "id"
            case display = "display"
            case subscriptionID = "subscription_id"
            case conditions = "conditions"
            case components = "components"
        }

        public init(identifier: String,
                    subscriptionID: String,
                    components: [Component],
                    display: CommonDisplay? = nil,
                    conditions: [Condition]? = nil) {

            self.identifier = identifier
            self.subscriptionID = subscriptionID
            self.components = components
            self.display = display
            self.conditions = conditions
        }

        public override func isEqual(_ object: Any?) -> Bool {
            guard let object = object as? ContactSubscriptionGroup else {
                return false
            }

            return self.identifier == object.identifier
            && self.display == object.display
            && self.subscriptionID == object.subscriptionID
            && self.conditions == object.conditions
            && self.components == object.components
        }

        /// Contact subscription group component.
        @objc(UAPreferenceContactSubscriptionGroupComponent)
        public class Component: NSObject, Decodable {

            /// The component's scopes.
            public var scopes: [ChannelScope] {
                return self._scopes.values
            }

            @objc(scopes)
            public let _scopes: ChannelScopes

            /// The component's display info.
            @objc
            public let display: CommonDisplay?

            enum CodingKeys: String, CodingKey {
                case _scopes = "scopes"
                case display = "display"
            }

            public init(scopes: [ChannelScope],
                        display: CommonDisplay? = nil) {
                self._scopes = ChannelScopes(scopes)
                self.display = display
            }

            public override func isEqual(_ object: Any?) -> Bool {
                guard let object = object as? Component else {
                    return false
                }

                return self.display == object.display && self._scopes == object._scopes
            }
        }
    }

    /// Contact subscription item info.
    @objc(UAPreferenceCenterConfigContactSubscription)
    public class ContactSubscription: NSObject, Decodable, PreferenceCenterConfigItem {

        /// The item's type.
        @objc
        public let type = PreferenceCenterConfigItemType.contactSubscription

        /// The item's identifier.
        @objc
        public let identifier: String

        /// The item's display info.
        @objc
        public let display: CommonDisplay?

        /// The item's display conditions.
        public let conditions: [Condition]?

        @objc(conditions)
        public var _conditions: [PreferenceConfigCondition]? {
            self.conditions?.map { $0.info }
        }

        /// The item's subscription ID.
        @objc
        public let subscriptionID: String

        /// The item's scopes.
        public var scopes: [ChannelScope] {
            return self._scopes.values
        }

        @objc(scopes)
        public let _scopes: ChannelScopes

        enum CodingKeys: String, CodingKey {
            case identifier = "id"
            case display = "display"
            case subscriptionID = "subscription_id"
            case conditions = "conditions"
            case _scopes = "scopes"
        }

        public init(identifier: String,
                    subscriptionID: String,
                    scopes: [ChannelScope],
                    display: CommonDisplay? = nil,
                    conditions: [Condition]? = nil) {

            self.identifier = identifier
            self.subscriptionID = subscriptionID
            self._scopes = ChannelScopes(scopes)
            self.display = display
            self.conditions = conditions
        }

        public override func isEqual(_ object: Any?) -> Bool {
            guard let object = object as? ContactSubscription else {
                return false
            }

            return self.identifier == object.identifier
            && self.display == object.display
            && self.subscriptionID == object.subscriptionID
            && self.conditions == object.conditions
            && self._scopes == object._scopes
        }
    }

    /// Alert item info.
    @objc(UAPreferenceCenterConfigAlert)
    public class Alert: NSObject, Decodable, PreferenceCenterConfigItem {

        @objc
        public let type = PreferenceCenterConfigItemType.alert

        /// The item's identifier.
        @objc
        public let identifier: String

        /// The item's display info.
        @objc
        public let display: Display?

        /// The item's display conditions.
        public let conditions: [Condition]?

        @objc(conditions)
        public var _conditions: [PreferenceConfigCondition]? {
            self.conditions?.map { $0.info }
        }

        /// The alert's button.
        @objc
        public let button: Button?

        enum CodingKeys: String, CodingKey {
            case identifier = "id"
            case display = "display"
            case conditions = "conditions"
            case button = "button"
        }

        public init(identifier: String,
                    display: Display? = nil,
                    conditions: [Condition]? = nil,
                    button: Button? = nil) {

            self.identifier = identifier
            self.display = display
            self.conditions = conditions
            self.button = button
        }

        public override func isEqual(_ object: Any?) -> Bool {
            guard let object = object as? Alert else {
                return false
            }

            return self.identifier == object.identifier
            && self.display == object.display
            && self.conditions == object.conditions
        }

        /// Alert button info.
        @objc(UAPreferenceCenterConfigAlertButton)
        public class Button: NSObject, Decodable {

            /// The buttton's text.
            @objc
            public let text: String

            /// The button's content description.
            @objc
            public let contentDescription: String?

            let actionJSON: AirshipJSON

            /// Actions paylaod to run on tap
            @objc
            public var actions: Any? {
                return self.actionJSON.unWrap()
            }

            enum CodingKeys: String, CodingKey {
                case text = "text"
                case contentDescription = "content_description"
                case actionJSON = "actions"
            }

            public init(text: String,
                        contentDescription: String? = nil) {

                self.text = text
                self.contentDescription = contentDescription
                self.actionJSON = .null
            }

            public override func isEqual(_ object: Any?) -> Bool {
                guard let object = object as? Button else {
                    return false
                }

                return self.text == object.text
                && self.contentDescription == object.contentDescription
                && self.actionJSON == object.actionJSON
            }
        }


        /// Alert display info
        @objc(UAPreferenceConfigAlertDisplay)
        public class Display: NSObject, Decodable {

            /// Title
            @objc
            public let title: String?

            /// Subtitle
            @objc
            public let subtitle: String?

            /// Icon URL
            @objc
            public let iconURL: String?

            enum CodingKeys: String, CodingKey {
                case title = "name"
                case subtitle = "description"
                case iconURL = "icon"
            }

            public init(title: String? = nil,
                        subtitle: String? = nil,
                        iconURL: String? = nil) {
                self.title = title
                self.subtitle = subtitle
                self.iconURL = iconURL
            }

            public override func isEqual(_ object: Any?) -> Bool {
                guard let object = object as? Display else {
                    return false
                }

                return self.title == object.title
                && self.subtitle == object.subtitle
                && self.iconURL == object.iconURL
            }
        }
    }


    /// Config item.
    public enum Item: Decodable, Equatable {
        case channelSubscription(ChannelSubscription)
        case contactSubscription(ContactSubscription)
        case contactSubscriptionGroup(ContactSubscriptionGroup)
        case alert(Alert)

        enum CodingKeys: String, CodingKey {
            case type = "type"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try PreferenceCenterConfigItemType.fromString(container.decode(String.self, forKey: .type))
            let singleValueContainer = try decoder.singleValueContainer()

            switch type {
            case .channelSubscription:
                self = .channelSubscription((try singleValueContainer.decode(ChannelSubscription.self)))
            case .contactSubscription:
                self = .contactSubscription((try singleValueContainer.decode(ContactSubscription.self)))
            case .contactSubscriptionGroup:
                self = .contactSubscriptionGroup((try singleValueContainer.decode(ContactSubscriptionGroup.self)))
            case .alert:
                self = .alert((try singleValueContainer.decode(Alert.self)))
            }
        }
    }


}

/// Condition types
@objc(UAPreferenceCenterConfigConditionType)
public enum PreferenceCenterConfigConditionType: Int, CustomStringConvertible, Equatable {

    /// Notification opt-in condition.
    case notificationOptIn

    var stringValue: String {
        switch self {
        case .notificationOptIn:
            return "notification_opt_in"
        }
    }

    static func fromString(_ value: String) throws -> PreferenceCenterConfigConditionType {
        switch value {
        case "notification_opt_in":
            return .notificationOptIn
        default:
            throw AirshipErrors.error("invalid condition \(value)")
        }
    }

    public var description: String {
        return stringValue
    }
}

/**
 * Condition
 */
@objc(UAPreferenceConfigCondition)
public protocol PreferenceConfigCondition {

    /**
     * Condition type.
     */
    @objc
    var type: PreferenceCenterConfigConditionType { get }
}

/// Item types.
@objc(UAPreferenceCenterConfigItemType)
public enum PreferenceCenterConfigItemType: Int, CustomStringConvertible, Equatable {

    /// Channel subscription type.
    case channelSubscription

    /// Contact subscription type.
    case contactSubscription

    /// Channel group subscription type.
    case contactSubscriptionGroup

    /// Alert type.
    case alert

    var stringValue: String {
        switch self {
        case .channelSubscription: return "channel_subscription"
        case .contactSubscription: return "contact_subscription"
        case .contactSubscriptionGroup: return "contact_subscription_group"
        case .alert: return "alert"
        }
    }

    static func fromString(_ value: String) throws -> PreferenceCenterConfigItemType {
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


/// Preference section item info.
@objc(UAPreferenceCenterConfigItem)
public protocol PreferenceCenterConfigItem {
    /// The type.
    @objc
    var type: PreferenceCenterConfigItemType { get }

    /// The identifier.
    @objc
    var identifier: String { get }
}


/// Preference config section type.
@objc(UAPreferenceCenterConfigSectionType)
public enum PreferenceCenterConfigSectionType: Int, CustomStringConvertible, Equatable {

    /// Common section type.
    case common

    /// Labeled section break type.
    case labeledSectionBreak

    var stringValue: String {
        switch self {
        case .common: return "section"
        case .labeledSectionBreak: return "labeled_section_break"
        }
    }

    static func fromString(_ value: String) throws -> PreferenceCenterConfigSectionType {
        switch value {
        case "section":
            return .common
        case "labeled_section_break":
            return .labeledSectionBreak
        default:
            throw AirshipErrors.error("invalid section \(value)")
        }
    }

    public var description: String {
        return stringValue
    }
}

/// Preference config section.
@objc(UAPreferenceCenterConfigSection)
public protocol PreferenceCenterConfigSection {

    /**
     * The section's type.
     */
    @objc
    var type: PreferenceCenterConfigSectionType { get }

    /**
     * The section's identifier.
     */
    @objc
    var identifier: String { get }
}

extension PreferenceCenterConfig.Item {
    var info: PreferenceCenterConfigItem {
        switch(self) {
        case .channelSubscription(let info): return info
        case .contactSubscription(let info): return info
        case .contactSubscriptionGroup(let info): return info
        case .alert(let info): return info
        }
    }
}

extension PreferenceCenterConfig.Section {
    var info: PreferenceCenterConfigSection {
        switch(self) {
        case .common(let info): return info
        case .labeledSectionBreak(let info): return info
        }
    }
}

extension PreferenceCenterConfig.Condition {
    var info: PreferenceConfigCondition {
        switch(self) {
        case .notificationOptIn(let info): return info
        }
    }
}

public extension PreferenceCenterConfig {
    func containsChannelSubscriptions() -> Bool {
        return self.sections.contains(where: { section in
            guard case .common(let info) = section else { return false }
            return info.items.contains(where: { item in
                return (item.info.type == .channelSubscription)
            })
        })
    }

    func containsContactSubscriptions() -> Bool {
        return self.sections.contains(where: { section in
            guard case .common(let info) = section else { return false }
            return info.items.contains(where: { item in
                return (item.info.type == .contactSubscription ||
                        item.info.type == .contactSubscriptionGroup)
            })
        })
    }
}
