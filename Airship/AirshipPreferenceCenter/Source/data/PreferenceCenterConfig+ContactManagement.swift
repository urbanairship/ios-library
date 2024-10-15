/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
public import AirshipCore
#endif

public extension PreferenceCenterConfig {

    /// Contact management item - base container object for contact management in the preference center
    class ContactManagementItem: Decodable, Equatable, PreferenceCenterConfigItem, @unchecked Sendable {
        /// The contact management item's type.
        public let type = PreferenceCenterConfigItemType.contactManagement

        /// The contact management item's identifier.
        public let identifier: String

        /// The contact management item's channel platform - for example: email or sms.
        public let platform: Platform

        // The common title and optional description
        public let display: CommonDisplay

        // The add prompt
        public let addChannel: AddChannel?

        /// The remove prompt
        public let removeChannel: RemoveChannel?

        /// The empty message label that's visible when no channels of this type have been added
        public let emptyMessage: String?

        /// The section's display conditions.
        public let conditions: [Condition]?

        enum CodingKeys: String, CodingKey {
            case identifier = "id"
            case platform = "platform"
            case display = "display"
            case emptyMessage = "empty_message"
            case addChannel = "add"
            case removeChannel = "remove"
            case registrationOptions = "registration_options"
            case conditions = "conditions"
            case email = "email"
            case sms = "sms"
        }

        public init(
            identifier: String,
            platform: Platform,
            display: CommonDisplay,
            emptyMessage: String? = nil,
            addChannel: AddChannel? = nil,
            removeChannel: RemoveChannel? = nil,
            conditions: [Condition]? = nil
        ) {
            self.identifier = identifier
            self.platform = platform
            self.display = display
            self.emptyMessage = emptyMessage
            self.addChannel = addChannel
            self.removeChannel = removeChannel
            self.conditions = conditions
        }

        public required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.identifier = try container.decode(String.self, forKey: .identifier)

            let platformType = try container.decode(String.self, forKey: CodingKeys.platform)
            switch platformType {
            case CodingKeys.email.rawValue:
                self.platform = .email(
                    try container.decode(Email.self, forKey: .registrationOptions)
                )
            case CodingKeys.sms.rawValue:
                self.platform = .sms(
                    try container.decode(SMS.self, forKey: .registrationOptions)
                )
            default:
                throw AirshipErrors.error("Unable to parse platform")
            }

            self.display = try container.decode(CommonDisplay.self, forKey: .display)
            self.addChannel = try container.decodeIfPresent(AddChannel.self, forKey: .addChannel)
            self.removeChannel = try container.decodeIfPresent(RemoveChannel.self, forKey: .removeChannel)
            self.emptyMessage = try container.decodeIfPresent(String.self, forKey: .emptyMessage)
            self.conditions = try container.decodeIfPresent([Condition].self, forKey: .conditions)
        }

        public static func == (
            lhs: ContactManagementItem,
            rhs: ContactManagementItem
        ) -> Bool {
            return lhs.identifier == rhs.identifier &&
            lhs.platform == rhs.platform &&
            lhs.display == rhs.display &&
            lhs.addChannel == rhs.addChannel &&
            lhs.removeChannel == rhs.removeChannel &&
            lhs.emptyMessage == rhs.emptyMessage &&
            lhs.conditions == rhs.conditions
        }

        /// Platform
        public enum Platform: Decodable, Equatable {
            case sms(SMS)
            case email(Email)

            var stringValue: String {
                switch self {
                case .sms: return "sms"
                case .email: return "email"
                }
            }

            var errorMessages: ErrorMessages? {
                switch self {
                case .sms(let sms):
                    return sms.errorMessages
                case .email(let email):
                    return email.errorMessages
                }
            }

            public var description: String {
                return stringValue
            }
        }

        /// Pending label that appears after channel list item is added. Resend button appears after interval.
        public struct PendingLabel: Decodable, Equatable {

            /// The interval in seconds to wait before resend button appears
            public let intervalInSeconds: Int

            /// The message that displays when a channel is pending
            public let message: String

            /// Resend button that appears after the given interval
            public let button: LabeledButton

            /// Resend prompt after successfully resending
            public let resendSuccessPrompt: ActionableMessage?

            enum CodingKeys: String, CodingKey {
                case intervalInSeconds = "interval"
                case message = "message"
                case button = "button"
                case resendSuccessPrompt = "on_success"
            }

            public init(
                intervalInSeconds: Int,
                message: String,
                button: LabeledButton,
                resendSuccessPrompt: ActionableMessage? = nil
            ) {
                self.intervalInSeconds = intervalInSeconds
                self.message = message
                self.button = button
                self.resendSuccessPrompt = resendSuccessPrompt
            }
        }

        /// Email registration options
        public struct Email: Decodable, Equatable {

            /// Text placeholder for email address
            public var placeholder: String?

            /// The label for the email address
            public var addressLabel: String

            /// Additional JSON payload
            public var properties: AirshipJSON?

            /// Label with resend button
            public var pendingLabel: PendingLabel

            /// Error messages that can result of attempting to add an email address
            public var errorMessages: ErrorMessages

            enum CodingKeys: String, CodingKey {
                case placeholder = "placeholder_text"
                case properties = "properties"
                case addressLabel = "address_label"
                case pendingLabel = "resend"
                case errorMessages = "error_messages"
            }

            public init(
                placeholder: String?,
                addressLabel: String,
                pendingLabel: PendingLabel,
                properties: AirshipJSON? = nil,
                errorMessages: ErrorMessages
            ) {
                self.placeholder = placeholder
                self.addressLabel = addressLabel
                self.pendingLabel = pendingLabel
                self.properties = properties
                self.errorMessages = errorMessages
            }
        }

        /// SMS registration options
        public struct SMS: Decodable, Equatable {

            /// List of sender ids - the identifiers for the senders of the SMS verification message
            public var senders: [SMSSenderInfo]

            /// Country code label
            public var countryLabel: String

            /// MSISDN Label
            public var msisdnLabel: String

            /// Label with resend button
            public var pendingLabel: PendingLabel

            /// Error messages that can result of attempting to add a MSISDN
            public var errorMessages: ErrorMessages

            enum CodingKeys: String, CodingKey {
                case senders = "senders"
                case countryLabel = "country_label"
                case msisdnLabel = "msisdn_label"
                case pendingLabel = "resend"
                case errorMessages = "error_messages"
            }

            public init(
                senders: [SMSSenderInfo],
                countryLabel: String,
                msisdnLabel: String,
                pendingLabel: PendingLabel,
                errorMessages: ErrorMessages
            ) {
                self.senders = senders
                self.countryLabel = countryLabel
                self.msisdnLabel = msisdnLabel
                self.pendingLabel = pendingLabel
                self.errorMessages = errorMessages
            }
        }

        /// Reusable container for holding a title and optional description.
        public struct CommonDisplay: Decodable, Equatable {

            /// Title text.
            public let title: String

            /// Subtitle text.
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

        /// The label message that appears when a channel listing is empty.
        public struct EmptyMessage: Decodable, Equatable {

            /// The empty message's text.
            public let text: String

            /// The empty message's content description.
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
        }

        /// The container for the add prompt button and resulting add prompt.
        public struct AddChannel: Decodable, Equatable {

            /// The add channel prompt view that appears when the add channel button is tapped.
            public let view: AddChannelPrompt

            /// The labeled button that surfaces the add channel prompt.
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

        /// The container for the remove channel button and resulting remove prompt for adding a channel to a channel list.
        public struct RemoveChannel: Decodable, Equatable {

            /// The remove channel prompt view that appears when the remove channel button is tapped.
            public let view: RemoveChannelPrompt

            /// The icon button that surfaces the remove channel prompt.
            public let button: IconButton

            enum CodingKeys: String, CodingKey {
                case view = "view"
                case button = "button"
            }

            public init(
                view: RemoveChannelPrompt,
                button: IconButton
            ) {

                self.view = view
                self.button = button
            }
        }

        public struct RemoveChannelPrompt: Decodable, Equatable {

            /// Optional additional prompt display info.
            public let display: PromptDisplay

            /// The prompt display that appears when a channel is removed.
            public let onSuccess: ActionableMessage?

            /// Close button info primarily for passing content descriptions.
            public let closeButton: IconButton?

            /// Cancel button.
            public let cancelButton: LabeledButton?

            /// The labeled button that initiates the removal of a channel on tap.
            public let submitButton: LabeledButton?

            enum CodingKeys: String, CodingKey {
                case display = "display"
                case onSuccess = "on_success"
                case submitButton = "submit_button"
                case closeButton = "close_button"
                case cancelButton = "cancel_button"
            }

            public init(
                display: PromptDisplay,
                onSuccess: ActionableMessage? = nil,
                submitButton: LabeledButton? = nil,
                closeButton: IconButton? = nil,
                cancelButton: LabeledButton? = nil
            ) {
                self.display = display
                self.onSuccess = onSuccess
                self.submitButton = submitButton
                self.closeButton = closeButton
                self.cancelButton = cancelButton
            }
        }

        /// A more dynamic version of common display that includes a footer and error message.
        public struct PromptDisplay: Decodable, Equatable {

            /// Title text.
            public let title: String

            /// Body text.
            public let body: String?

            /// Footer text that can contain markdown.
            public let footer: String?

            enum CodingKeys: String, CodingKey {
                case title = "title"
                case body = "description"
                case footer = "footer"
            }

            public init(
                title: String,
                body: String? = nil,
                footer: String? = nil
            ) {

                self.title = title
                self.body = body
                self.footer = footer
            }
        }

        public struct AddChannelPrompt: Decodable, Equatable {

            /// The item text display.
            public let display: PromptDisplay

            /// The submission message.
            public let onSubmit: ActionableMessage?

            /// The close button.
            public let closeButton: IconButton?

            /// The cancel prompt button.
            public let cancelButton: LabeledButton?

            /// The submit prompt button.
            public let submitButton: LabeledButton

            enum CodingKeys: String, CodingKey {
                case display = "display"
                case onSubmit = "on_submit"
                case cancelButton = "cancel_button"
                case submitButton = "submit_button"
                case closeButton = "close_button"
            }

            public init(
                display: PromptDisplay,
                onSubmit: ActionableMessage? = nil,
                cancelButton: LabeledButton? = nil,
                submitButton: LabeledButton,
                closeButton: IconButton? = nil
            ) {
                self.display = display
                self.onSubmit = onSubmit
                self.cancelButton = cancelButton
                self.submitButton = submitButton
                self.closeButton = closeButton
            }
        }

        public struct IconButton: Codable, Equatable {
            /// The button's content description.
            public let contentDescription: String?

            enum CodingKeys: String, CodingKey {
                case contentDescription = "content_description"
            }

            public init(
                contentDescription: String? = nil
            ) {
                self.contentDescription = contentDescription
            }
        }

        /// Alert button info.
        public struct LabeledButton: Decodable, Equatable {

            /// The button's text.
            public let text: String

            /// The button's content description.
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
        }

        /// Alert display info
        public struct ActionableMessage: Decodable, Equatable {

            /// Title text.
            public let title: String

            /// Body text.
            public let body: String?

            /// Labeled button for submitting the action or closing the prompt.
            public let button: LabeledButton

            enum CodingKeys: String, CodingKey {
                case title = "name"
                case body = "description"
                case button = "button"
            }

            public init(
                title: String,
                body: String?,
                button: LabeledButton
            ) {
                self.title = title
                self.body = body
                self.button = button
            }
        }

        /// Error message container for showing error messages on the add channel prompt
        public struct ErrorMessages: Codable, Equatable {
            var invalidMessage: String
            var defaultMessage: String

            enum CodingKeys: String, CodingKey {
                case invalidMessage = "invalid"
                case defaultMessage = "default"
            }
        }

        /// The info used to populate the add channel prompt sender input for SMS.
        public struct SMSSenderInfo: Decodable, Identifiable, Equatable, Hashable {
            public var id: String {
                return senderId
            }

            /// The senderId is the number from which the SMS is sent.
            public var senderId: String

            /// Placeholder text.
            public var placeholderText: String

            /// Country calling code. Examples: (1, 33, 44)
            public var countryCode: String

            /// Country display name.
            public var displayName: String

            enum CodingKeys: String, CodingKey {
                case senderId = "sender_id"
                case placeholderText = "placeholder_text"
                case countryCode = "country_calling_code"
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

            static let none = SMSSenderInfo(
                senderId: "none",
                placeholderText: "none",
                countryCode: "none",
                displayName: "none"
            )
        }
    }
}

extension PreferenceCenterConfig.ContactManagementItem.Platform: Encodable {}

extension PreferenceCenterConfig.ContactManagementItem.PendingLabel: Encodable {}

extension PreferenceCenterConfig.ContactManagementItem.Email: Encodable {}

extension PreferenceCenterConfig.ContactManagementItem.SMS: Encodable {}

extension PreferenceCenterConfig.ContactManagementItem.CommonDisplay: Encodable {}

extension PreferenceCenterConfig.ContactManagementItem.AddChannel: Encodable {}

extension PreferenceCenterConfig.ContactManagementItem.RemoveChannel: Encodable {}

extension PreferenceCenterConfig.ContactManagementItem.RemoveChannelPrompt: Encodable {}

extension PreferenceCenterConfig.ContactManagementItem.PromptDisplay: Encodable {}

extension PreferenceCenterConfig.ContactManagementItem.AddChannelPrompt: Encodable {}

extension PreferenceCenterConfig.ContactManagementItem.LabeledButton: Encodable {}

extension PreferenceCenterConfig.ContactManagementItem.ActionableMessage: Encodable {}

extension PreferenceCenterConfig.ContactManagementItem.SMSSenderInfo: Encodable {}
