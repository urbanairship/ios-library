/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Preference center config.
@objc(UAPreferenceCenterConfig)
public final class PreferenceCenterConfig: NSObject, Decodable, Sendable {

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

    public override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? PreferenceCenterConfig else {
            return false
        }

        return self.identifier == object.identifier
            && self.sections == object.sections
            && self.display == object.display
            && self.options == object.options
    }

    public static func == (lhs: PreferenceCenterConfig, rhs: PreferenceCenterConfig) -> Bool {
        return lhs.identifier == rhs.identifier &&
        lhs.sections == rhs.sections &&
        lhs.display == rhs.display &&
        lhs.options == rhs.options
    }

    /// Config options.
    @objc(UAPreferenceCenterConfigOptions)
    public final class Options: NSObject, Decodable, Sendable {

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

            if let mergeChannelDataToContact = try? container.decode(
                Bool.self,
                forKey: .mergeChannelDataToContact
            ) {
                self.mergeChannelDataToContact = mergeChannelDataToContact
            } else {
                self.mergeChannelDataToContact = false
            }
        }

        public override func isEqual(_ object: Any?) -> Bool {
            guard let object = object as? Options else {
                return false
            }

            return self.mergeChannelDataToContact
                == object.mergeChannelDataToContact
        }
    }

    /// Common display info
    @objc(UAPreferenceConfigCommonDisplay)
    public final class CommonDisplay: NSObject, Decodable, Sendable {

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

            return self.title == object.title
                && self.subtitle == object.subtitle
        }

        public static func == (lhs: PreferenceCenterConfig.CommonDisplay, rhs: PreferenceCenterConfig.CommonDisplay) -> Bool {
            return lhs.title == rhs.title && lhs.subtitle == rhs.subtitle
        }
    }

    
    @objc(UAPreferenceCenterConfigOptInCondition)
    public final class OptInCondition: NSObject, Decodable, PreferenceConfigCondition, Sendable
    {

        @objc(UANotificationOptInConditionStatus)
        public enum OptInStatus: Int, Equatable, Sendable {
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
            let optInStatus = try container.decode(
                String.self,
                forKey: .optInStatus
            )

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
            guard let object = object as? OptInCondition else {
                return false
            }

            return self.optInStatus == object.optInStatus
        }
    }

    /**
     * Typed conditions.
     */
    public enum Condition: Decodable, Equatable, Sendable {
        case notificationOptIn(OptInCondition)

        enum CodingKeys: String, CodingKey {
            case type = "type"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try PreferenceCenterConfigConditionType.fromString(
                container.decode(String.self, forKey: .type)
            )
            let singleValueContainer = try decoder.singleValueContainer()

            switch type {
            case .notificationOptIn:
                self = .notificationOptIn(
                    try singleValueContainer.decode(
                        OptInCondition.self
                    )
                )
            }
        }
    }

    /// Common section.
    @objc(UAPreferenceCenterConfigCommonSection)
    public final class CommonSection: NSObject, Decodable,
        PreferenceCenterConfigSection
    {

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

        public init(
            identifier: String,
            items: [Item],
            display: CommonDisplay? = nil,
            conditions: [Condition]? = nil
        ) {
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

        public static func == (lhs: PreferenceCenterConfig.CommonSection, rhs: PreferenceCenterConfig.CommonSection) -> Bool {
            return lhs.identifier == rhs.identifier &&
            lhs.items == rhs.items &&
            lhs.display == rhs.display &&
            lhs.conditions == rhs.conditions
        }
    }

    /// Labeled section break info.
    @objc(UAPreferenceLabeledSectionBreak)
    public final class LabeledSectionBreak: NSObject, Decodable,
        PreferenceCenterConfigSection
    {

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

        public init(
            identifier: String,
            display: CommonDisplay? = nil,
            conditions: [Condition]? = nil
        ) {

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

    /// Contact Management section.
    @objc(UAPreferenceCenterConfigContactManagementSection)
    public final class ContactManagementSection: NSObject, Decodable,
                                      PreferenceCenterConfigSection
    {

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

        public init(
            identifier: String,
            items: [Item],
            display: CommonDisplay? = nil,
            conditions: [Condition]? = nil
        ) {
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

    /// Preference config section.
    public enum Section: Decodable, Equatable, Sendable {

        /// Common section
        case common(CommonSection)

        /// Labeled section break
        case labeledSectionBreak(LabeledSectionBreak)

        enum CodingKeys: String, CodingKey {
            case type = "type"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try PreferenceCenterConfigSectionType.fromString(
                container.decode(String.self, forKey: .type)
            )
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

        public static func == (lhs: PreferenceCenterConfig.Section, rhs: PreferenceCenterConfig.Section) -> Bool {
            switch (lhs, rhs) {
            case (.common(let lhsSection), .common(let rhsSection)):
                return lhsSection == rhsSection
            case (.labeledSectionBreak(let lhsSection), .labeledSectionBreak(let rhsSection)):
                return lhsSection == rhsSection
            default:
                return false
            }
        }
    }
    
    /// Channel subscription item info.
    @objc(UAPreferenceCenterConfigChannelSubscription)
    public final class ChannelSubscription: NSObject, Decodable, PreferenceCenterConfigItem, Sendable {

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

        public init(
            identifier: String,
            subscriptionID: String,
            display: CommonDisplay? = nil,
            conditions: [Condition]? = nil
        ) {

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
    public final class ContactSubscriptionGroup: NSObject, Decodable,
        PreferenceCenterConfigItem
    {

        /// The item's type.
        @objc
        public let type = PreferenceCenterConfigItemType
            .contactSubscriptionGroup

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

        public init(
            identifier: String,
            subscriptionID: String,
            components: [Component],
            display: CommonDisplay? = nil,
            conditions: [Condition]? = nil
        ) {

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
        public final class Component: NSObject, Decodable, Sendable {

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

            public init(
                scopes: [ChannelScope],
                display: CommonDisplay? = nil
            ) {
                self._scopes = ChannelScopes(scopes)
                self.display = display
            }

            public override func isEqual(_ object: Any?) -> Bool {
                guard let object = object as? Component else {
                    return false
                }

                return self.display == object.display
                    && self._scopes == object._scopes
            }
        }
    }

    /// Contact subscription item info.
    @objc(UAPreferenceCenterConfigContactSubscription)
    public final class ContactSubscription: NSObject, Decodable,
        PreferenceCenterConfigItem
    {

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

        public init(
            identifier: String,
            subscriptionID: String,
            scopes: [ChannelScope],
            display: CommonDisplay? = nil,
            conditions: [Condition]? = nil
        ) {

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
    public final class Alert: NSObject, Decodable, PreferenceCenterConfigItem {

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

        public init(
            identifier: String,
            display: Display? = nil,
            conditions: [Condition]? = nil,
            button: Button? = nil
        ) {

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
        public final class Button: NSObject, Decodable, Sendable {

            /// The button's text.
            @objc
            public let text: String

            /// The button's content description.
            @objc
            public let contentDescription: String?

            let actionJSON: AirshipJSON

            /// Actions payload to run on tap
            @objc
            public var actions: Any? {
                return self.actionJSON.unWrap()
            }

            enum CodingKeys: String, CodingKey {
                case text = "text"
                case contentDescription = "content_description"
                case actionJSON = "actions"
            }

            public init(
                text: String,
                contentDescription: String? = nil
            ) {

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
        public final class Display: NSObject, Decodable, Sendable {

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

            public init(
                title: String? = nil,
                subtitle: String? = nil,
                iconURL: String? = nil
            ) {
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
    
    /// Contact management item
    public class ContactManagementItem: NSObject, Decodable, PreferenceCenterConfigItem, @unchecked Sendable {

        @objc
        public let type = PreferenceCenterConfigItemType.contactManagement
        
        /// The contact management item's identifier.
        @objc
        public let identifier: String
        
        public let platform: Platform
        
        // The display prompt
        public let display: CommonDisplay

        // The add prompt
        public let addPrompt: AddPrompt?
        
        /// The remove prompt
        public let removePrompt: RemoveChannel?

        /// The empty label that's visible when no channels of this type have been added
        public let emptyLabel: String?

        public let registrationOptions: RegistrationOptions
        
        /// The section's display conditions.
        public let conditions: [Condition]?
        
        enum CodingKeys: String, CodingKey {
            case identifier = "id"
            case platform = "platform"
            case display = "display"
            case emptyLabel = "empty_label"
            case addPrompt = "add"
            case removePrompt = "remove"
            case registrationOptions = "registration_options"
            case conditions = "conditions"
        }
        
        public init(
            identifier: String,
            platform: Platform,
            display: CommonDisplay,
            emptyLabel: String?,
            addPrompt: AddPrompt?,
            removePrompt: RemoveChannel?,
            registrationOptions: RegistrationOptions,
            conditions: [Condition]
        ) {
            self.identifier = identifier
            self.platform = platform
            self.display = display
            self.emptyLabel = emptyLabel
            self.addPrompt = addPrompt
            self.removePrompt = removePrompt
            self.registrationOptions = registrationOptions
            self.conditions = conditions
        }
        
        public enum Platform: String, Decodable, Sendable {
            
            // SMS platform
            case sms
            
            // Email platform
            case email
            
            var stringValue: String {
                switch self {
                case .sms: return "sms"
                case .email: return "email"
                }
            }

            static func fromString(_ value: String) throws
                -> RegistrationOptionsType
            {
                switch value {
                case "sms": return .sms
                case "email": return .email
                default:
                    throw AirshipErrors.error("invalid item \(value)")
                }
            }

            public var description: String {
                return stringValue
            }
        }

        @objc(PreferenceCenterPendingLabel)
        public class PendingLabel: NSObject, Decodable {

            /// The interval in seconds to wait before resend button appears
            @objc
            public let intervalInSeconds: Int

            /// The message that displays when a channel is pending
            @objc
            public let message: String

            /// Resend button that appears after the given interval
            @objc
            public let button: LabeledButton

            /// Resend button that appears after the given interval
            @objc
            public let resendSuccessPrompt: ActionableMessage

            enum CodingKeys: String, CodingKey {
                case intervalInSeconds = "interval"
                case message = "message"
                case button = "button"
                case resendSuccessPrompt = "on_success"
            }

            public init(intervalInSeconds: Int, message: String, button: LabeledButton, resendSuccessPrompt: ActionableMessage) {
                self.intervalInSeconds = intervalInSeconds
                self.message = message
                self.button = button
                self.resendSuccessPrompt = resendSuccessPrompt
            }
        }

        @objc(PreferenceCenterEmailRegistrationOption)
        public class EmailRegistrationOption: NSObject, Decodable {
            
            @objc
            public var placeholder: String
            
            @objc
            public var addressLabel: String

            public var properties: AirshipJSON?

            /// Label with resend button
            @objc
            public var pendingLabel: PendingLabel

            enum CodingKeys: String, CodingKey {
                case placeholder = "placeholder_text"
                case properties = "properties"
                case addressLabel = "address_label"
                case pendingLabel = "resend"
            }
            
            public init(placeholder: String, addressLabel: String, pendingLabel: PendingLabel, properties: AirshipJSON? = nil) {
                self.placeholder = placeholder
                self.addressLabel = addressLabel
                self.pendingLabel = pendingLabel
                self.properties = properties
            }
        }
        
        @objc(PreferenceCenterSmsRegistrationOption)
        public class SmsRegistrationOption: NSObject, Decodable {
            
            @objc
            public var senders: [SmsSenderInfo]

            @objc
            public var countryLabel: String

            @objc
            public var msisdnLabel: String

            /// Label with resend button
            @objc
            public var pendingLabel: PendingLabel

            enum CodingKeys: String, CodingKey {
                case senders = "senders"
                case countryLabel = "country_label"
                case msisdnLabel = "msisdn_label"
                case pendingLabel = "resend"
            }
            
            public init(senders: [SmsSenderInfo], countryLabel: String, msisdnLabel: String, pendingLabel: PendingLabel) {
                self.senders = senders
                self.countryLabel = countryLabel
                self.msisdnLabel = msisdnLabel
                self.pendingLabel = pendingLabel
            }
        }
        /// Item types.
        @objc(UAPreferenceCenterConfigRegistrationOptionsType)
        public enum RegistrationOptionsType: Int, CustomStringConvertible,
            Equatable
        {
            /// SMS type.
            case sms

            /// Email type.
            case email
            
            var stringValue: String {
                switch self {
                case .sms: return "sms"
                case .email: return "email"
                }
            }

            static func fromString(_ value: String) throws
                -> RegistrationOptionsType
            {
                switch value {
                case "sms": return .sms
                case "email": return .email
                default:
                    throw AirshipErrors.error("invalid item \(value)")
                }
            }

            public var description: String {
                return stringValue
            }
        }
        
        /// Registration options.
        public enum RegistrationOptions: Decodable, Equatable {
            case sms(SmsRegistrationOption)
            case email(EmailRegistrationOption)

            enum CodingKeys: String, CodingKey {
                case type = "type"
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let type = try RegistrationOptionsType.fromString(
                    container.decode(String.self, forKey: .type)
                )
                let singleValueContainer = try decoder.singleValueContainer()

                switch type {
                case .sms:
                    self = .sms(
                        (try singleValueContainer.decode(SmsRegistrationOption.self))
                    )
                case .email:
                    self = .email(
                        (try singleValueContainer.decode(EmailRegistrationOption.self))
                    )
                }
            }

            public var isSms: Bool {
                switch self {
                case .sms:
                    return true
                case .email:
                    return false
                }
            }
        }
        
        
        @objc(UAPreferenceCenterConfigDisplayPrompt)
        public class CommonDisplay: NSObject, Decodable {
            
            @objc
            public let title: String
            
            @objc
            public let subtitle: String?
            
            enum CodingKeys: String, CodingKey {
                case title = "name"
                case subtitle = "description"
            }
            
            public init(title: String, subtitle: String? = nil) {
                self.title = title
                self.subtitle = subtitle
            }
        }
           
        @objc(UAPreferenceCenterConfigAddPrompt)
        public class AddPrompt: NSObject, Decodable {
            
            @objc
            public let view: AddChannelPrompt
            
            @objc
            public let button: LabeledButton
            
            
            enum CodingKeys: String, CodingKey {
                case view = "view"
                case button = "button"
            }
            
            public init(
                view: AddChannelPrompt,
                button: LabeledButton
            ) {
                
                self.view = view
                self.button = button
            }
        }
        
        @objc(UAPreferenceCenterConfigRemoveChannel)
        public class RemoveChannel: NSObject, Decodable {
            
            @objc
            public let view: RemoveChannelPrompt
            
            @objc
            public let button: LabeledButton
            
            
            enum CodingKeys: String, CodingKey {
                case view = "view"
                case button = "button"
            }
            
            public init(
                view: RemoveChannelPrompt,
                button: LabeledButton
            ) {
                
                self.view = view
                self.button = button
            }
        }
        
        @objc(UAPreferenceCenterConfigRemoveChannelPrompt)
        public class RemoveChannelPrompt: NSObject, Decodable {
            
            @objc
            public let display: PromptDisplay
            
            @objc
            public let acceptButton: LabeledButton?

            enum CodingKeys: String, CodingKey {
                case display = "display"
                case acceptButton = "submit_button"
            }
            
            public init(
                display: PromptDisplay,
                acceptButton: LabeledButton?
            ) {
                
                self.display = display
                self.acceptButton = acceptButton
            }
        }
        
        @objc(UAPreferenceCenterConfigPromptDisplay)
        public class PromptDisplay: NSObject, Decodable {
            
            /// The item's display info.
            @objc
            public let title: String
            
            @objc
            public let body: String?
            
            @objc
            public let footer: String?
            
            @objc
            public let errorMessage: String?
            
            enum CodingKeys: String, CodingKey {
                case title = "title"
                case body = "body"
                case footer = "footer"
                case errorMessage = "error_message"
            }
            
            public init(
                title: String,
                body: String? = nil,
                footer: String? = nil,
                errorMessage: String?
            ) {
                
                self.title = title
                self.body = body
                self.footer = footer
                self.errorMessage = errorMessage
            }
        }
        
        @objc(UAPreferenceCenterConfigAddChannelPrompt)
        public class AddChannelPrompt: NSObject, Decodable {
            
            /// The item's identifier.
            @objc
            public let display: PromptDisplay
            
            /// The success message.
            @objc
            public let onSuccess: ActionableMessage?

            /// The error messages
            public let errorMessages: ErrorMessages?

            /// The cancel prompt's button.
            @objc
            public let cancelButton: LabeledButton
            
            /// The submit prompt's button.
            @objc
            public let submitButton: LabeledButton
            
            enum CodingKeys: String, CodingKey {
                case display = "display"
                case onSuccess = "on_success"
                case errorMessages = "error_messages"
                case cancelButton = "cancel_button"
                case submitButton = "submit_button"
            }
            
            public init(
                display: PromptDisplay,
                onSuccess: ActionableMessage? = nil,
                errorMessages: ErrorMessages? = nil,
                cancelButton: LabeledButton,
                submitButton: LabeledButton
            ) {
                self.display = display
                self.onSuccess = onSuccess
                self.errorMessages = errorMessages
                self.cancelButton = cancelButton
                self.submitButton = submitButton
            }
        }
        
        
        /// Alert button info.
        @objc(UAPreferenceCenterConfigPromptButton)
        public class LabeledButton: NSObject, Decodable {

            /// The button's text.
            @objc
            public let text: String

            /// The button's content description.
            @objc
            public let contentDescription: String?

            enum CodingKeys: String, CodingKey {
                case text = "text"
                case contentDescription = "content_description"
            }

            public init(
                text: String,
                contentDescription: String? = nil
            ) {

                self.text = text
                self.contentDescription = contentDescription
            }

            public override func isEqual(_ object: Any?) -> Bool {
                guard let object = object as? LabeledButton else {
                    return false
                }

                return self.text == object.text
                    && self.contentDescription == object.contentDescription
            }
        }

        /// Alert display info
        @objc(UAPreferenceConfigActionableMessage)
        public class ActionableMessage: NSObject, Decodable {

            /// Title
            @objc
            public let title: String

            /// Body
            @objc
            public let body: String

            /// Button
            @objc
            public let button: LabeledButton
            
            enum CodingKeys: String, CodingKey {
                case title = "name"
                case body = "description"
                case button = "button"
            }

            public init(
                title: String,
                body: String,
                button: LabeledButton
            ) {
                self.title = title
                self.body = body
                self.button = button
            }

            public override func isEqual(_ object: Any?) -> Bool {
                guard let object = object as? ActionableMessage else {
                    return false
                }

                return self.title == object.title
                && self.body == object.body
            }
        }

        public struct ErrorMessages: Codable {
            var invalidMessage: String
            var defaultMessage: String

            enum CodingKeys: String, CodingKey {
                case invalidMessage = "invalid"
                case defaultMessage = "default"
            }
        }

        @objc
        public class RePromptOptions: NSObject, Decodable {

            var interval: Int
            var message: String
            var button: LabeledButton
            
            enum CodingKeys: String, CodingKey {
                case interval = "interval"
                case message = "message"
                case button = "button"
            }
            
            public init(interval: Int, message: String, button: LabeledButton) {
                self.interval = interval
                self.message = message
                self.button = button
            }
        }
        
        @objc
        public class SmsSenderInfo: NSObject, Decodable, Identifiable {

            /// The senderId is the number from which the SMS is sent
            var senderId: String
            var placeholderText: String
            var countryCode: String
            var displayName: String
            
            enum CodingKeys: String, CodingKey {
                case senderId = "sender_id"
                case placeholderText = "placeholder_text"
                case countryCode = "country_code"
                case displayName = "display_name"
            }
            
            public init(
                senderId: String,
                placeholderText: String,
                countryCode: String,
                displayName: String
            ) {
                self.senderId = senderId
                self.placeholderText = placeholderText
                self.countryCode = countryCode
                self.displayName = displayName
            }
            
            public override func isEqual(_ object: Any?) -> Bool {
                guard let object = object as? SmsSenderInfo else {
                    return false
                }

                return self.senderId == object.senderId
                && self.placeholderText == object.placeholderText
                && self.countryCode == object.countryCode
                && self.displayName == object.placeholderText
            }
            
            static let none = SmsSenderInfo(
                senderId: "none",
                placeholderText: "none",
                countryCode: "none",
                displayName: "none"
            )
            
        }
    }
    
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

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try PreferenceCenterConfigItemType.fromString(
                container.decode(String.self, forKey: .type)
            )
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
@objc(UAPreferenceCenterConfigConditionType)
public enum PreferenceCenterConfigConditionType: Int, CustomStringConvertible,
    Equatable, Sendable
{

    /// Notification opt-in condition.
    case notificationOptIn


    var stringValue: String {
        switch self {
        case .notificationOptIn:
            return "notification_opt_in"
        }
    }

    static func fromString(_ value: String) throws
        -> PreferenceCenterConfigConditionType
    {
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

/// Condition
@objc(UAPreferenceConfigCondition)
public protocol PreferenceConfigCondition: Sendable {

    /**
     * Condition type.
     */
    @objc
    var type: PreferenceCenterConfigConditionType { get }
}

/// Item types.
@objc(UAPreferenceCenterConfigItemType)
public enum PreferenceCenterConfigItemType: Int, CustomStringConvertible,
    Equatable, Sendable
{
    /// Channel subscription type.
    case channelSubscription

    /// Contact subscription type.
    case contactSubscription

    /// Channel group subscription type.
    case contactSubscriptionGroup

    /// Alert type.
    case alert

    /// Contact management
    case contactManagement
    
    var stringValue: String {
        switch self {
        case .channelSubscription: return "channel_subscription"
        case .contactSubscription: return "contact_subscription"
        case .contactSubscriptionGroup: return "contact_subscription_group"
        case .alert: return "alert"
        case .contactManagement: return "contact_management"
        }
    }

    static func fromString(_ value: String) throws
        -> PreferenceCenterConfigItemType
    {
        switch value {
        case "channel_subscription": return .channelSubscription
        case "contact_subscription": return .contactSubscription
        case "contact_subscription_group": return .contactSubscriptionGroup
        case "alert": return .alert
        case "contact_management": return .contactManagement
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
public protocol PreferenceCenterConfigItem: Sendable {
    /// The type.
    @objc
    var type: PreferenceCenterConfigItemType { get }

    /// The identifier.
    @objc
    var identifier: String { get }
}
    
/// Preference config section type.
@objc(UAPreferenceCenterConfigSectionType)
public enum PreferenceCenterConfigSectionType: Int, CustomStringConvertible,
    Equatable, Sendable
{
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

    static func fromString(_ value: String) throws
        -> PreferenceCenterConfigSectionType
    {
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
public protocol PreferenceCenterConfigSection: Sendable {

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
    var info: PreferenceCenterConfigSection {
        switch self {
        case .common(let info): return info
        case .labeledSectionBreak(let info): return info
        }
    }
}

extension PreferenceCenterConfig.Condition {
    var info: PreferenceConfigCondition {
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

public extension PreferenceCenterConfig {
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
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(sections, forKey: .sections)
        try container.encodeIfPresent(display, forKey: .display)
        try container.encodeIfPresent(options, forKey: .options)
    }
}

extension PreferenceCenterConfig.Options: Encodable {}

extension PreferenceCenterConfig.CommonDisplay: Encodable {}

extension PreferenceCenterConfig.OptInCondition: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(optInStatus.rawValue, forKey: .optInStatus)
    }
}

extension PreferenceCenterConfig.Condition: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .notificationOptIn(let condition):
            try container.encode(condition.type.description, forKey: .type)
            try condition.encode(to: encoder)
        }
    }
}

extension PreferenceCenterConfig.CommonSection: Encodable {}

extension PreferenceCenterConfig.LabeledSectionBreak: Encodable {}

extension PreferenceCenterConfig.Section: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .common(let section):
            try container.encode(section.type.description, forKey: .type)
            try section.encode(to: encoder)
        case .labeledSectionBreak(let section):
            try container.encode(section.type.description, forKey: .type)
            try section.encode(to: encoder)
        }
    }
}

extension PreferenceCenterConfig.ChannelSubscription: Encodable {}

extension PreferenceCenterConfig.ContactSubscriptionGroup: Encodable {}

extension PreferenceCenterConfig.ContactSubscriptionGroup.Component: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(_scopes, forKey: ._scopes)
        try container.encode(display, forKey: .display)
    }
}

extension PreferenceCenterConfig.ContactSubscription: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(identifier, forKey: .identifier)
        try container.encode(display, forKey: .display)
        try container.encode(subscriptionID, forKey: .subscriptionID)
//        try container.encode(_conditions, forKey: .conditions)
        try container.encode(_scopes, forKey: ._scopes)
    }
}

extension ChannelScopes: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values.map { $0.rawValue })
    }
}

extension PreferenceCenterConfig.Alert: Encodable {}

extension PreferenceCenterConfig.Alert.Button: Encodable {}

extension PreferenceCenterConfigConditionType : Encodable {}

extension PreferenceCenterConfig.Alert.Display: Encodable {}

extension PreferenceCenterConfig.ContactManagementItem: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(identifier, forKey: .identifier)
        try container.encode(platform, forKey: .platform)
        try container.encode(display, forKey: .display)
        try container.encodeIfPresent(emptyLabel, forKey: .emptyLabel)
        try container.encodeIfPresent(addPrompt, forKey: .addPrompt)
        try container.encodeIfPresent(removePrompt, forKey: .removePrompt)
        try container.encode(registrationOptions, forKey: .registrationOptions)
        try container.encodeIfPresent(conditions, forKey: .conditions)
    }
}

extension PreferenceCenterConfig.ContactManagementItem.Platform: Encodable {}

extension PreferenceCenterConfig.ContactManagementItem.PendingLabel: Encodable {}

extension PreferenceCenterConfig.ContactManagementItem.EmailRegistrationOption: Encodable {}

extension PreferenceCenterConfig.ContactManagementItem.SmsRegistrationOption: Encodable {}

extension PreferenceCenterConfig.ContactManagementItem.CommonDisplay: Encodable {}

extension PreferenceCenterConfig.ContactManagementItem.AddPrompt: Encodable {}

extension PreferenceCenterConfig.ContactManagementItem.RemoveChannel: Encodable {}

extension PreferenceCenterConfig.ContactManagementItem.RemoveChannelPrompt: Encodable {}

extension PreferenceCenterConfig.ContactManagementItem.PromptDisplay: Encodable {}

extension PreferenceCenterConfig.ContactManagementItem.AddChannelPrompt: Encodable {}

extension PreferenceCenterConfig.ContactManagementItem.LabeledButton: Encodable {}

extension PreferenceCenterConfig.ContactManagementItem.ActionableMessage: Encodable {}

extension PreferenceCenterConfig.ContactManagementItem.RePromptOptions: Encodable {}

extension PreferenceCenterConfig.ContactManagementItem.SmsSenderInfo: Encodable {}

extension PreferenceCenterConfig.ContactManagementItem.RegistrationOptions: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .sms(let option):
            try container.encode(PreferenceCenterConfig.ContactManagementItem.RegistrationOptionsType.sms.description, forKey: .type)
            try option.encode(to: encoder)
        case .email(let option):
            try container.encode(PreferenceCenterConfig.ContactManagementItem.RegistrationOptionsType.email.description, forKey: .type)
            try option.encode(to: encoder)
        }
    }
}

extension PreferenceCenterConfig.Item: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .channelSubscription(let item):
            try container.encode(item.type.description, forKey: .type)
            try item.encode(to: encoder)
        case .contactSubscription(let item):
            try container.encode(item.type.description, forKey: .type)
            try item.encode(to: encoder)
        case .contactSubscriptionGroup(let item):
            try container.encode(item.type.description, forKey: .type)
            try item.encode(to: encoder)
        case .alert(let item):
            try container.encode(item.type.description, forKey: .type)
            try item.encode(to: encoder)
        case .contactManagement(let item):
            try container.encode(item.type.description, forKey: .type)
            try item.encode(to: encoder)
        }
    }
}
