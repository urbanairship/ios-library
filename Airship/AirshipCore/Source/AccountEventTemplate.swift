/* Copyright Airship and Contributors */

import Foundation

public extension CustomEvent {

    /// Account template
    enum AccountTemplate: Sendable {
        /// Account registered
        case registered

        /// User logged in
        case loggedIn

        /// User logged out
        case loggedOut

        fileprivate static let templateName: String = "account"

        fileprivate var eventName: String {
            return switch self {
            case .registered: "registered_account"
            case .loggedIn: "logged_in"
            case .loggedOut: "logged_out"
            }
        }
    }

    /// Additional acount template properties
    struct AccountProperties: Encodable, Sendable {

        /// User ID.
        public var userID: String?

        /// The event's category.
        public var category: String?

        /// The event's type.
        public var type: String?

        /// If the value is a lifetime value or not.
        public var isLTV: Bool

        public init(
            category: String? = nil,
            type: String? = nil,
            isLTV: Bool = false,
            userID: String? = nil
        ) {
            self.userID = userID
            self.category = category
            self.type = type
            self.isLTV = isLTV
        }

        enum CodingKeys: String, CodingKey {
            case userID = "user_id"
            case category
            case type
            case isLTV = "ltv"
        }
    }

    /// Constructs a custom event using the account template.
    /// - Parameters:
    ///     - accountTemplate: The account template.
    ///     - properties: Optional additional properties
    ///     - encoder: Encoder used to encode the additional properties. Defaults to `CustomEvent.defaultEncoder`.
    init(
        accountTemplate: AccountTemplate,
        properties: AccountProperties = AccountProperties(),
        encoder: @autoclosure () -> JSONEncoder = CustomEvent.defaultEncoder()
    ) {
        self = .init(name: accountTemplate.eventName)
        self.templateType = AccountTemplate.templateName

        do {
            try self.setProperties(properties, encoder: encoder())
        } catch {
            /// Should never happen so we are just catching the exception and logging
            AirshipLogger.error("Failed to generate event \(error)")
        }
    }
}
