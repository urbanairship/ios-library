/* Copyright Airship and Contributors */

import Foundation

public extension CustomEvent {

    /// Search template
    enum SearchTemplate: Sendable {
        /// Search
        case search

        fileprivate static let templateName: String = "search"

        fileprivate var eventName: String {
            return switch self {
            case .search: "search"
            }
        }
    }

    /// Additional search template properties
    struct SearchProperties: Encodable, Sendable {
        /// The event's ID.
        public var id: String?

        /// The search query.
        public var query: String?

        /// The total search results
        public var totalResults: Int?

        /// The event's category.
        public var category: String?

        /// The event's type.
        public var type: String?

        /// If the value is a lifetime value or not.
        public var isLTV: Bool

        public init(
            id: String? = nil,
            category: String? = nil,
            type: String? = nil,
            isLTV: Bool = false,
            query: String? = nil,
            totalResults: Int? = nil
        ) {
            self.id = id
            self.query = query
            self.totalResults = totalResults
            self.category = category
            self.type = type
            self.isLTV = isLTV
        }

        enum CodingKeys: String, CodingKey {
            case id
            case query
            case totalResults = "total_results"
            case category
            case type
            case isLTV = "ltv"
        }
    }

    /// Constructs a custom event using the search template.
    /// - Parameters:
    ///     - accountTemplate: The search template.
    ///     - properties: Optional additional properties
    ///     - encoder: Encoder used to encode the additional properties. Defaults to `CustomEvent.defaultEncoder`.
    init(
        searchTemplate: SearchTemplate,
        properties: SearchProperties = SearchProperties(),
        encoder: @autoclosure () -> JSONEncoder = CustomEvent.defaultEncoder()
    ) {
        self = .init(name: searchTemplate.eventName)
        self.templateType = SearchTemplate.templateName

        do {
            try self.setProperties(properties, encoder: encoder())
        } catch {
            /// Should never happen so we are just catching the exception and logging
            AirshipLogger.error("Failed to generate event \(error)")
        }
    }
}

