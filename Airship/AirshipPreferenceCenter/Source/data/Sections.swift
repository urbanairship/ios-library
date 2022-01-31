/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif


@objc(UAPreferenceSectionType)
public enum SectionType: Int, CustomStringConvertible {
    case common
    case labeledSectionBreak
    
    var stringValue: String {
        switch self {
        case .common: return "section"
        case .labeledSectionBreak: return "labeled_section_break"
        }
    }
    
    static func fromString(_ value: String) throws -> SectionType {
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
     * Section type enum.
     */
    @objc
    var sectionType: SectionType { get }
    
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
        
    /**
     * Optional display conditions.
     */
    @objc
    var conditions: [Condition]? { get }
}

/**
 * Common section.
 */
@objc(UAPreferenceCommonSection)
public class CommonSection : NSObject, Decodable, Section {
    
    let typedConditions: [TypedConditions]?
    let typedItems: [TypedItems]
    
    @objc
    public let type = SectionType.common.stringValue
    
    @objc
    public let sectionType = SectionType.common
    
    @objc
    public let identifier: String
    
    @objc
    public let display: CommonDisplay?
    
    @objc
    public lazy var conditions: [Condition]? = {
        self.typedConditions?.map { $0.condition }
    }()
    
    @objc
    public lazy var items: [Item] = {
            return typedItems.map { $0.item }
    }()
    
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case display = "display"
        case typedItems = "items"
        case typedConditions = "conditions"
    }
}

/**
 * Labled break section.
 */
@objc(UAPreferenceLabeledSectionBreakSection)
public class LabeledSectionBreakSection : NSObject, Decodable, Section {
    
    let typedConditions: [TypedConditions]?
    
    @objc
    public let type = SectionType.labeledSectionBreak.stringValue
    
    @objc
    public let sectionType = SectionType.labeledSectionBreak
    
    @objc
    public let identifier: String
    
    @objc
    public let display: CommonDisplay?
    
    @objc
    public let items: [Item] = []
    
    @objc
    public lazy var conditions: [Condition]? = {
        self.typedConditions?.map { $0.condition }
    }()
   
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case display = "display"
        case typedConditions = "conditions"
    }
}

enum TypedSections : Decodable {
    case common(CommonSection)
    case labeledSectionBreak(LabeledSectionBreakSection)

    enum CodingKeys: String, CodingKey {
        case type = "type"
    }
    
    var section: Section {
        switch(self) {
        case .common(let section): return section
        case .labeledSectionBreak(let section): return section
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try SectionType.fromString(container.decode(String.self, forKey: .type))
        let singleValueContainer = try decoder.singleValueContainer()

        switch type {
        case .common:
            self = .common((try singleValueContainer.decode(CommonSection.self)))
        case .labeledSectionBreak:
            self = .labeledSectionBreak((try singleValueContainer.decode(LabeledSectionBreakSection.self)))
        }
    }
}
