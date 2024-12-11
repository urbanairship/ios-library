/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
public import AirshipCore
#endif

/// Preference center config.
public struct PreferenceCenterConfig: Decodable, Sendable, Equatable {

    /// The config's identifier.
    public var identifier: String

    /// The config's sections.
    public var sections: [Section]

    /// The config's display info.
    public var display: CommonDisplay?

    /**
     * The config's options.
     */
    public var options: Options?

    public init(
        identifier: String,
        sections: [Section],
        display: CommonDisplay? = nil,
        options: Options? = nil
    ) {
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

    /// Config options.
    public struct Options: Decodable, Sendable, Equatable {

        /**
         * The config identifier.
         */
        public var mergeChannelDataToContact: Bool?

        enum CodingKeys: String, CodingKey {
            case mergeChannelDataToContact = "merge_channel_data_to_contact"
        }

        public init(mergeChannelDataToContact: Bool?) {
            self.mergeChannelDataToContact = mergeChannelDataToContact
        }
    }

    /// Common display info
    public struct CommonDisplay: Decodable, Sendable, Equatable {

        /// Title
        public var title: String?

        // Subtitle
        public var subtitle: String?

        public init(title: String? = nil, subtitle: String? = nil) {
            self.title = title
            self.subtitle = subtitle
        }

        enum CodingKeys: String, CodingKey {
            case title = "name"
            case subtitle = "description"
        }
    }

    public struct NotificationOptInCondition: Decodable, PreferenceConfigCondition, Sendable
    {

        public enum OptInStatus: String, Equatable, Sendable, Codable {
            case optedIn = "opt_in"
            case optedOut = "opt_out"
        }

        public let type = PreferenceCenterConfigConditionType.notificationOptIn

        public var optInStatus: OptInStatus

        enum CodingKeys: String, CodingKey {
            case optInStatus = "when_status"
        }

        public init(optInStatus: OptInStatus) {
            self.optInStatus = optInStatus
        }
    }

    /**
     * Typed conditions.
     */
    public enum Condition: Decodable, Equatable, Sendable {
        case notificationOptIn(NotificationOptInCondition)

        enum CodingKeys: String, CodingKey {
            case type = "type"
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(PreferenceCenterConfigConditionType.self, forKey: .type)
            let singleValueContainer = try decoder.singleValueContainer()

            switch type {
            case .notificationOptIn:
                self = .notificationOptIn(
                    try singleValueContainer.decode(
                        NotificationOptInCondition.self
                    )
                )
            }
        }
    }

    /// Common section.
    public struct CommonSection: Decodable, PreferenceCenterConfigSection {

        /// The section's type.
        public let type = PreferenceCenterConfigSectionType.common

        /// The section's identifier.
        public var id: String

        /// The section's items.
        public var items: [Item]

        /// The section's display info.
        public var display: CommonDisplay?

        /// The section's display conditions.
        public var conditions: [Condition]?

        public init(
            id: String,
            items: [Item],
            display: CommonDisplay? = nil,
            conditions: [Condition]? = nil
        ) {
            self.id = id
            self.items = items
            self.display = display
            self.conditions = conditions
        }

        enum CodingKeys: String, CodingKey {
            case id = "id"
            case display = "display"
            case items = "items"
            case conditions = "conditions"
        }
    }

    /// Labeled section break info.
    public struct LabeledSectionBreak: Decodable, PreferenceCenterConfigSection {


        /// The section's type.
        public let type = PreferenceCenterConfigSectionType.labeledSectionBreak

        /// The section's identifier.
        public var id: String

        /// The section's display info.
        public var display: CommonDisplay?

        /// The section's display conditions.
        public var conditions: [Condition]?

        public init(
            id: String,
            display: CommonDisplay? = nil,
            conditions: [Condition]? = nil
        ) {

            self.id = id
            self.display = display
            self.conditions = conditions
        }

        enum CodingKeys: String, CodingKey {
            case id = "id"
            case display = "display"
            case conditions = "conditions"
        }
    }

    /// Contact Management section.
    public struct ContactManagementSection: Decodable, PreferenceCenterConfigSection {
        /// The section's type.
        public let type = PreferenceCenterConfigSectionType.common

        /// The section's identifier.
        public var id: String

        /// The section's items.
        public var items: [Item]

        /// The section's display info.
        public var display: CommonDisplay?

        /// The section's display conditions.
        public var conditions: [Condition]?

        public init(
            id: String,
            items: [Item],
            display: CommonDisplay? = nil,
            conditions: [Condition]? = nil
        ) {
            self.id = id
            self.items = items
            self.display = display
            self.conditions = conditions
        }

        enum CodingKeys: String, CodingKey {
            case id = "id"
            case display = "display"
            case items = "items"
            case conditions = "conditions"
        }
    }

    /// Preference config section.
    public enum Section: Decodable, Equatable, Sendable {

        /// Common section
        case common(CommonSection)

        /// Labeled section break
        case labeledSectionBreak(LabeledSectionBreak)

        enum CodingKeys: String, CodingKey {
            case type = "type"
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(PreferenceCenterConfigSectionType.self, forKey: .type)
            let singleValueContainer = try decoder.singleValueContainer()

            switch type {
            case .common:
                self = .common(
                    (try singleValueContainer.decode(CommonSection.self))
                )
            case .labeledSectionBreak:
                self = .labeledSectionBreak(
                    (try singleValueContainer.decode(LabeledSectionBreak.self))
                )
            }
        }
    }
    
    /// Channel subscription item info.
    public struct ChannelSubscription: Decodable, Equatable, PreferenceCenterConfigItem {

        /// The item's type.
        public let type = PreferenceCenterConfigItemType.channelSubscription

        /// The item's identifier.
        public var id: String

        /// The item's subscription ID.
        public var subscriptionID: String

        /// The item's display info.
        public var display: CommonDisplay?

        /// The item's display conditions.
        public var conditions: [Condition]?


        enum CodingKeys: String, CodingKey {
            case id = "id"
            case display = "display"
            case subscriptionID = "subscription_id"
            case conditions = "conditions"
        }

        public init(
            id: String,
            subscriptionID: String,
            display: CommonDisplay? = nil,
            conditions: [Condition]? = nil
        ) {

            self.id = id
            self.subscriptionID = subscriptionID
            self.display = display
            self.conditions = conditions
        }
    }

    /// Group contact subscription item info.
    public struct ContactSubscriptionGroup: Decodable, Equatable, PreferenceCenterConfigItem {

        /// The item's type.
        public let type = PreferenceCenterConfigItemType
            .contactSubscriptionGroup

        /// The item's identifier.
        public var id: String

        /// The item's subscription ID.
        public var subscriptionID: String

        /// Components
        public var components: [Component]

        /// The item's display info.
        public var display: CommonDisplay?

        /// The item's display conditions.
        public var conditions: [Condition]?

        enum CodingKeys: String, CodingKey {
            case id = "id"
            case display = "display"
            case subscriptionID = "subscription_id"
            case conditions = "conditions"
            case components = "components"
        }

        public init(
            id: String,
            subscriptionID: String,
            components: [Component],
            display: CommonDisplay? = nil,
            conditions: [Condition]? = nil
        ) {

            self.id = id
            self.subscriptionID = subscriptionID
            self.components = components
            self.display = display
            self.conditions = conditions
        }

        /// Contact subscription group component.
        public struct Component: Decodable, Sendable, Equatable {

            /// The component's scopes.
            public var scopes: [ChannelScope]

            /// The component's display info.
            public var display: CommonDisplay?

            enum CodingKeys: String, CodingKey {
                case scopes = "scopes"
                case display = "display"
            }

            public init(
                scopes: [ChannelScope],
                display: CommonDisplay? = nil
            ) {
                self.scopes = scopes
                self.display = display
            }
        }
    }

    /// Contact subscription item info.
    public struct ContactSubscription: Decodable, PreferenceCenterConfigItem, Equatable {

        /// The item's type.
        public let type = PreferenceCenterConfigItemType.contactSubscription

        /// The item's identifier.
        public var id: String

        /// The item's display info.
        public var display: CommonDisplay?

        /// The item's display conditions.
        public let conditions: [Condition]?

        /// The item's subscription ID.
        public var subscriptionID: String

        /// The item's scopes.
        public var scopes: [ChannelScope]

        enum CodingKeys: String, CodingKey {
            case id = "id"
            case display = "display"
            case subscriptionID = "subscription_id"
            case conditions = "conditions"
            case scopes = "scopes"
        }

        public init(
            id: String,
            subscriptionID: String,
            scopes: [ChannelScope],
            display: CommonDisplay? = nil,
            conditions: [Condition]? = nil
        ) {

            self.id = id
            self.subscriptionID = subscriptionID
            self.scopes = scopes
            self.display = display
            self.conditions = conditions
        }

    }

    /// Alert item info.
    public struct Alert: Decodable, PreferenceCenterConfigItem, Equatable {

        public let type = PreferenceCenterConfigItemType.alert

        /// The item's identifier.
        public let id: String

        /// The item's display info.
        public var display: Display?

        /// The item's display conditions.
        public var conditions: [Condition]?

        /// The alert's button.
        public var button: Button?

        enum CodingKeys: String, CodingKey {
            case id = "id"
            case display = "display"
            case conditions = "conditions"
            case button = "button"
        }

        public init(
            id: String,
            display: Display? = nil,
            conditions: [Condition]? = nil,
            button: Button? = nil
        ) {

            self.id = id
            self.display = display
            self.conditions = conditions
            self.button = button
        }

        /// Alert button info.
        public struct Button: Decodable, Sendable, Equatable {

            /// The button's text.
            public var text: String

            /// The button's content description.
            public var contentDescription: String?

            /// Actions payload to run on tap
            public var actionJSON: AirshipJSON

            enum CodingKeys: String, CodingKey {
                case text = "text"
                case contentDescription = "content_description"
                case actionJSON = "actions"
            }

            public init(
                text: String,
                contentDescription: String? = nil,
                actionJSON: AirshipJSON = .null
            ) {

                self.text = text
                self.contentDescription = contentDescription
                self.actionJSON = actionJSON
            }
        }

        /// Alert display info
        public struct Display: Decodable, Sendable, Equatable {

            /// Title
            public var title: String?

            /// Subtitle
            public var subtitle: String?

            /// Icon URL
            public var iconURL: String?

            enum CodingKeys: String, CodingKey {
                case title = "name"
                case subtitle = "description"
                case iconURL = "icon"
            }

            public init(
                title: String? = nil,
                subtitle: String? = nil,
                iconURL: String? = nil
            ) {
                self.title = title
                self.subtitle = subtitle
                self.iconURL = iconURL
            }
        }
    }
    
    /// Contact management item

    
    /// Config item.
    public enum Item: Decodable, Equatable, Sendable {
        case channelSubscription(ChannelSubscription)
        case contactSubscription(ContactSubscription)
        case contactSubscriptionGroup(ContactSubscriptionGroup)
        case alert(Alert)
        case contactManagement(ContactManagementItem)

        enum CodingKeys: String, CodingKey {
            case type = "type"
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(PreferenceCenterConfigItemType.self, forKey: .type)
            let singleValueContainer = try decoder.singleValueContainer()

            switch type {
            case .channelSubscription:
                self = .channelSubscription(
                    (try singleValueContainer.decode(ChannelSubscription.self))
                )
            case .contactSubscription:
                self = .contactSubscription(
                    (try singleValueContainer.decode(ContactSubscription.self))
                )
            case .contactSubscriptionGroup:
                self = .contactSubscriptionGroup(
                    (try singleValueContainer.decode(
                        ContactSubscriptionGroup.self
                    ))
                )
            case .alert:
                self = .alert((try singleValueContainer.decode(Alert.self)))
            case .contactManagement:
                self = .contactManagement((try singleValueContainer.decode(ContactManagementItem.self)))
            }
        }
    }

}

/// Condition types
public enum PreferenceCenterConfigConditionType: String, Equatable, Sendable, Codable {
    /// Notification opt-in condition.
    case notificationOptIn = "notification_opt_in"
}

/// Condition
public protocol PreferenceConfigCondition: Sendable, Equatable {

    /**
     * Condition type.
     */
    var type: PreferenceCenterConfigConditionType { get }
}

/// Item types.
public enum PreferenceCenterConfigItemType: String, Equatable, Sendable, Codable {
    /// Channel subscription type.
    case channelSubscription = "channel_subscription"

    /// Contact subscription type.
    case contactSubscription = "contact_subscription"

    /// Channel group subscription type.
    case contactSubscriptionGroup = "contact_subscription_group"

    /// Alert type.
    case alert

    /// Contact management
    case contactManagement = "contact_management"
}

/// Preference section item info.
public protocol PreferenceCenterConfigItem: Sendable, Identifiable {
    /// The type.
    var type: PreferenceCenterConfigItemType { get }

    /// The identifier.
    var id: String { get }
}
    
/// Preference config section type.
public enum PreferenceCenterConfigSectionType: String, Equatable, Sendable, Codable {
    /// Common section type.
    case common = "section"

    /// Labeled section break type.
    case labeledSectionBreak = "labeled_section_break"
}

/// Preference config section.
public protocol PreferenceCenterConfigSection: Sendable, Equatable, Identifiable {

    /**
     * The section's type.
     */
    var type: PreferenceCenterConfigSectionType { get }

    /**
     * The section's identifier.
     */
    var id: String { get }
}

extension PreferenceCenterConfig.Item {
    var info: any PreferenceCenterConfigItem {
        switch self {
        case .channelSubscription(let info): return info
        case .contactSubscription(let info): return info
        case .contactSubscriptionGroup(let info): return info
        case .alert(let info): return info
        case .contactManagement(let info): return info
        }
    }
}

extension PreferenceCenterConfig.Section {
    var info: any PreferenceCenterConfigSection {
        switch self {
        case .common(let info): return info
        case .labeledSectionBreak(let info): return info
        }
    }
}

extension PreferenceCenterConfig.Condition {
    var info: any PreferenceConfigCondition {
        switch self {
        case .notificationOptIn(let info): return info
        }
    }
}

extension PreferenceCenterConfig {
    public func containsChannelSubscriptions() -> Bool {
        return self.sections.contains(where: { section in
            guard case .common(let info) = section else { return false }
            return info.items.contains(where: { item in
                return (item.info.type == .channelSubscription)
            })
        })
    }

    public func containsContactSubscriptions() -> Bool {
        return self.sections.contains(where: { section in
            guard case .common(let info) = section else { return false }
            return info.items.contains(where: { item in
                return
                    (item.info.type == .contactSubscription
                    || item.info.type == .contactSubscriptionGroup)
            })
        })
    }
    
    public func containsContactManagement() -> Bool {
        return self.sections.contains(where: { section in
            guard case .common(let info) = section else { return false }
            return info.items.contains(where: { item in
                return item.info.type == .contactManagement
            })
        })
    }
}

// MARK: Encodable support for testing

extension PreferenceCenterConfig {
    func prettyPrintedJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(self)

        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw NSError(domain: "JSONEncoding", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert JSON data to string."])
        }

        return jsonString
    }
}

extension PreferenceCenterConfig: Encodable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(sections, forKey: .sections)
        try container.encodeIfPresent(display, forKey: .display)
        try container.encodeIfPresent(options, forKey: .options)
    }
}

extension PreferenceCenterConfig.Options: Encodable {}

extension PreferenceCenterConfig.CommonDisplay: Encodable {}

extension PreferenceCenterConfig.NotificationOptInCondition: Encodable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(optInStatus.rawValue, forKey: .optInStatus)
    }
}

extension PreferenceCenterConfig.Condition: Encodable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .notificationOptIn(let condition):
            try container.encode(condition.type, forKey: .type)
            try condition.encode(to: encoder)
        }
    }
}

extension PreferenceCenterConfig.CommonSection: Encodable {}

extension PreferenceCenterConfig.LabeledSectionBreak: Encodable {}

extension PreferenceCenterConfig.Section: Encodable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .common(let section):
            try container.encode(section.type, forKey: .type)
            try section.encode(to: encoder)
        case .labeledSectionBreak(let section):
            try container.encode(section.type, forKey: .type)
            try section.encode(to: encoder)
        }
    }
}

extension PreferenceCenterConfig.ChannelSubscription: Encodable {}

extension PreferenceCenterConfig.ContactSubscriptionGroup: Encodable {}

extension PreferenceCenterConfig.ContactSubscriptionGroup.Component: Encodable {}

extension PreferenceCenterConfig.ContactSubscription: Encodable {}

extension PreferenceCenterConfig.Alert: Encodable {}

extension PreferenceCenterConfig.Alert.Button: Encodable {}

extension PreferenceCenterConfig.Alert.Display: Encodable {}

extension PreferenceCenterConfig.ContactManagementItem: Encodable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(platform, forKey: .platform)
        try container.encode(display, forKey: .display)
        try container.encodeIfPresent(emptyMessage, forKey: .emptyMessage)
        try container.encodeIfPresent(addChannel, forKey: .addChannel)
        try container.encodeIfPresent(removeChannel, forKey: .removeChannel)
        try container.encodeIfPresent(conditions, forKey: .conditions)
    }
}

extension PreferenceCenterConfig.Item: Encodable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .channelSubscription(let item):
            try container.encode(item.type, forKey: .type)
            try item.encode(to: encoder)
        case .contactSubscription(let item):
            try container.encode(item.type, forKey: .type)
            try item.encode(to: encoder)
        case .contactSubscriptionGroup(let item):
            try container.encode(item.type, forKey: .type)
            try item.encode(to: encoder)
        case .alert(let item):
            try container.encode(item.type, forKey: .type)
            try item.encode(to: encoder)
        case .contactManagement(let item):
            try container.encode(item.type, forKey: .type)
            try item.encode(to: encoder)
        }
    }
}
