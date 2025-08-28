/* Copyright Airship and Contributors */



public extension CustomEvent {

    /// Media event types
    enum MediaTemplate: Sendable {
        /// Browsed media
        case browsed

        /// Consumed media
        case consumed

        /// Shared media
        /// - Parameters:
        ///     - source: Optional source.
        ///     - medium: Optional medium.
        case shared(source: String? = nil, medium: String? = nil)

        /// Starred media
        case starred

        fileprivate static let templateName: String = "media"

        fileprivate var eventName: String {
            return switch self {
            case .browsed: "browsed_content"
            case .consumed: "consumed_content"
            case .shared: "shared_content"
            case .starred: "starred_content"
            }
        }
    }

    /// Additional media template properties
    struct MediaProperties: Encodable, Sendable {
        /// The event's ID.
        public var id: String?

        /// The event's category.
        public var category: String?

        /// The event's type.
        public var type: String?

        /// The event's description.
        public var eventDescription: String?

        /// The event's author.
        public var author: String?

        /// The event's published date.
        public var publishedDate: Date?

        /// If the event is a feature
        public var isFeature: Bool?

        /// If the value is a lifetime value or not.
        public var isLTV: Bool

        var source: String? = nil
        var medium: String? = nil

        public init(
            id: String? = nil,
            category: String? = nil,
            type: String? = nil,
            eventDescription: String? = nil,
            isLTV: Bool = false,
            author: String? = nil,
            publishedDate: Date? = nil,
            isFeature: Bool? = nil
        ) {
            self.id = id
            self.category = category
            self.type = type
            self.eventDescription = eventDescription
            self.isLTV = isLTV
            self.author = author
            self.publishedDate = publishedDate
            self.isFeature = isFeature
        }

        enum CodingKeys: String, CodingKey {
            case isLTV = "ltv"
            case isFeature = "feature"
            case id
            case category
            case type
            case source
            case medium
            case eventDescription = "description"
            case author
            case publishedDate = "published_date"
        }
    }

    /// Constructs a custom event using the media template.
    /// - Parameters:
    ///     - mediaTemplate: The media template.
    ///     - properties: Media properties.
    ///     - encoder: Encoder used to encode the additional properties. Defaults to `CustomEvent.defaultEncoder`.
    init(
        mediaTemplate: MediaTemplate,
        properties: MediaProperties = MediaProperties(),
        encoder: @autoclosure () -> JSONEncoder = CustomEvent.defaultEncoder()
    ) {
        self = .init(name: mediaTemplate.eventName)
        self.templateType = MediaTemplate.templateName

        var mutableProperties = properties

        switch (mediaTemplate) {
        case .browsed: break
        case .starred: break
        case .consumed: break
        case .shared(source: let source, medium: let medium):
            mutableProperties.source = source
            mutableProperties.medium = medium
        }

        do {
            try self.setProperties(mutableProperties, encoder: encoder())
        } catch {
            /// Should never happen so we are just catching the exception and logging
            AirshipLogger.error("Failed to generate event \(error)")
        }
    }
}

