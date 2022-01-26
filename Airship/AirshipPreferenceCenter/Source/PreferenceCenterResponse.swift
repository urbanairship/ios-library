/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#endif

/**
 * Preference center config.
 */
@objc(UAPreferenceCenterConfig)
public class PreferenceCenterConfig : NSObject, Decodable {
    
    /**
     * The config identifier.
     */
    @objc
    public let identifier: String
    
    let _sections: [SectionWrapper]
    
    /**
     * The preference center sections.
     */
    @objc
    public lazy var sections: [Section] = {
        return _sections.map { $0.section }
    }()
    
    /**
     * Optional common display info.
     */
    @objc
    public let display: CommonDisplay?
    
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case _sections = "sections"
        case display = "display"
    }
}

/**
 * Common display info.
 */
@objc(UAPreferenceCommonDisplay)
public class CommonDisplay : NSObject, Decodable {
    
    /**
     * The optional name/title.
     */
    @objc
    public let title: String?
    
    /**
     * The optional description/subtitle.
     */
    @objc
    public let subtitle: String?
    
    enum CodingKeys: String, CodingKey {
        case title = "name"
        case subtitle = "description"
    }
}

/**
 * Preference section item.
 */
@objc(UAPreferenceItem)
public protocol Item  {
    
    /**
     * The item type.
     */
    @objc
    var type: String { get }
    
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
}

/**
 * Preference section.
 */
@objc(UAPreferenceSection)
public protocol Section {
    
    /**
     * Section type.
     */
    @objc
    var type: String { get }
    
    /**
     * Section identifier.
     */
    @objc
    var identifier: String { get }
    
    /**
     * Optional display info.
     */
    @objc
    var display: CommonDisplay? { get }
    
    /**
     * Section items.
     */
    @objc
    var items: [Item] { get }
}

/**
 * Common section.
 */
@objc(UAPreferenceCommonSection)
public class CommonSection : NSObject, Decodable, Section {
    
    @objc
    public let type = SectionType.common.rawValue
    
    @objc
    public let identifier: String
    
    @objc
    public let display: CommonDisplay?
    
    let _items: [ItemWrapper]
    
    @objc
    public lazy var items: [Item] = {
        return _items.map { $0.item }
    }()
    
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case display = "display"
        case _items = "items"
    }
}

/**
 * Channel subscription item.
 */
@objc(UAPreferenceChannelSubscriptionItem)
public class ChannelSubscriptionItem : NSObject, Decodable, Item {
    
    @objc
    public let type = ItemTypes.channelSubscription.rawValue
    
    @objc
    public let identifier: String
    
    @objc
    public let display: CommonDisplay?
    
    /**
     * The subcription identifier.
     */
    @objc
    public let subscriptionID: String

    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case display = "display"
        case subscriptionID = "subscription_id"
    }
}

struct PrefrenceCenterResponse : Decodable {
    let config: PreferenceCenterConfig

    enum CodingKeys: String, CodingKey {
        case config = "form"
    }
}

struct ItemWrapper : Decodable {
    let item: Item

    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ItemTypes.self, forKey: .type)
        let singleValueContainer = try decoder.singleValueContainer()

        switch type {
        case .channelSubscription:
            self.item = try singleValueContainer.decode(ChannelSubscriptionItem.self)
        default:
            AirshipLogger.error("Unexpected type: \(type)")
            throw AirshipErrors.parseError("Unexpected type: \(type)")
        }
    }
}

struct SectionWrapper : Decodable {
    let section: Section

    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(SectionType.self, forKey: .type)
        let singleValueContainer = try decoder.singleValueContainer()

        switch type {
        case .common:
            self.section = try singleValueContainer.decode(CommonSection.self)
        default:
            AirshipLogger.error("Unexpected type: \(type)")
            throw AirshipErrors.parseError("Unexpected type: \(type)")
        }
    }
}

enum SectionType: String {
    case common = "section"
    case sectionBreak = "labeled_section_break"
    case unknown
}

enum ItemTypes: String {
    case channelSubscription = "channel_subscription"
    case unknown
}

extension SectionType : Decodable {}
extension ItemTypes : Decodable {}
