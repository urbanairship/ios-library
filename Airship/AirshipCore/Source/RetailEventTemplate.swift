/* Copyright Airship and Contributors */




public extension CustomEvent {

    /// Retail templates
    enum RetailTemplate: Sendable {
        /// Browsed
        case browsed

        /// Added to cart
        case addedToCart

        /// Starred
        case starred

        /// Purchased
        case purchased

        /// Shared
        /// - Parameters:
        ///     - source: Optional source.
        ///     - medium: Optional medium.
        case shared(source: String? = nil, medium: String? = nil)

        /// Added to wishlist
        /// - Parameters:
        ///     - id: Optional id.
        ///     - name: Optional name.
        case wishlist(id: String? = nil, name: String? = nil)

        fileprivate static let templateName: String = "retail"

        fileprivate var eventName: String {
            return switch self {
            case .browsed: "browsed"
            case .addedToCart: "added_to_cart"
            case .starred: "starred_product"
            case .purchased: "purchased"
            case .shared: "shared_product"
            case .wishlist: "wishlist"
            }
        }
    }

    /// Additional retail template properties
    struct RetailProperties: Encodable, Sendable {
        /// The event's ID.
        public var id: String?

        /// The event's category.
        public var category: String?

        /// The event's type.
        public var type: String?

        /// The event's description.
        public var eventDescription: String?

        /// The brand.
        public var brand: String?

        /// If its a new item or not.
        public var isNewItem: Bool?

        /// The currency.
        public var currency: String?

        /// If the value is a lifetime value or not.
        public var isLTV: Bool

        // Set from templates
        fileprivate var source: String? = nil
        fileprivate var medium: String? = nil
        fileprivate var wishlistName: String? = nil
        fileprivate var wishlistID: String? = nil

        public init(
            id: String? = nil,
            category: String? = nil,
            type: String? = nil,
            eventDescription: String? = nil,
            isLTV: Bool = false,
            brand: String? = nil,
            isNewItem: Bool? = nil,
            currency: String? = nil
        ) {
            self.id = id
            self.category = category
            self.type = type
            self.eventDescription = eventDescription
            self.brand = brand
            self.isNewItem = isNewItem
            self.currency = currency
            self.isLTV = isLTV
        }

        enum CodingKeys: String, CodingKey {
            case id
            case category
            case type
            case eventDescription = "description"
            case brand
            case isNewItem = "new_item"
            case currency
            case isLTV = "ltv"
            case source
            case medium
            case wishlistName = "wishlist_name"
            case wishlistID = "wishlist_id"
        }
    }

    /// Constructs a custom event using the retail template.
    /// - Parameters:
    ///     - accountTemplate: The retail template.
    ///     - properties: Optional additional properties
    ///     - encoder: Encoder used to encode the additional properties. Defaults to `CustomEvent.defaultEncoder`.
    init(
        retailTemplate: RetailTemplate,
        properties: RetailProperties = RetailProperties(),
        encoder: @autoclosure () -> JSONEncoder = CustomEvent.defaultEncoder()
    ) {
        self = .init(name: retailTemplate.eventName)
        self.templateType = RetailTemplate.templateName

        var mutableProperties = properties

        switch retailTemplate {
        case .browsed: break
        case .addedToCart: break
        case .starred: break
        case .purchased: break
        case .shared(source: let source, medium: let medium):
            mutableProperties.source = source
            mutableProperties.medium = medium
        case .wishlist(id: let id, name: let name):
            mutableProperties.wishlistID = id
            mutableProperties.wishlistName = name
        }

        do {
            try self.setProperties(mutableProperties, encoder: encoder())
        } catch {
            /// Should never happen so we are just catching the exception and logging
            AirshipLogger.error("Failed to generate event \(error)")
        }
    }
}
