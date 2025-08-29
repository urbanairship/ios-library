/* Copyright Airship and Contributors */

import Foundation

/*
 * <tag_selector>   := <tag> | <not> | <and> | <or>
 * <tag>            := { "tag": string }
 * <not>            := { "not": <tag_selector> }
 * <and>            := { "and": [<tag_selector>, <tag_selector>, ...] }
 * <or>             := { "or": [<tag_selector>, <tag_selector>, ...] }
 */

/// NOTE: For internal use only. :nodoc:
public indirect enum DeviceTagSelector: Codable, Sendable, Equatable {
    case or([DeviceTagSelector])
    case not(DeviceTagSelector)
    case and([DeviceTagSelector])
    case tag(String)


    public func evaluate(tags: Set<String>) -> Bool {
        switch (self) {
        case .tag(let tag):
            return tags.contains(tag)
        case .or(let selectors):
            return selectors.contains { selector in
                selector.evaluate(tags: tags)
            }
        case .not(let selector):
            return !selector.evaluate(tags: tags)
        case .and(let selectors):
            return selectors.allSatisfy { selector in
                selector.evaluate(tags: tags)
            }
        }
    }

    enum CodingKeys: CodingKey {
        case or
        case not
        case and
        case tag
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var allKeys = ArraySlice(container.allKeys)
        guard let selectorType = allKeys.popFirst(), allKeys.isEmpty else {
            throw DecodingError.typeMismatch(
                DeviceTagSelector.self,
                DecodingError.Context(codingPath: container.codingPath, debugDescription: "Invalid number of keys found, expected one.", underlyingError: nil)
            )
        }

        switch selectorType {
        case .or:
            self = .or(try container.decode([DeviceTagSelector].self, forKey: .or))
        case .not:
            self = .not(try container.decode(DeviceTagSelector.self, forKey: .not))
        case .and:
            self = .and(try container.decode([DeviceTagSelector].self, forKey: .and))
        case .tag:
            self = .tag(try container.decode(String.self, forKey: .tag))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .or(let selectors):
            try container.encode(selectors, forKey: .or)
        case .not(let selector):
            try container.encode(selector, forKey: .not)
        case .and(let selectors):
            try container.encode(selectors, forKey: .and)
        case .tag(let tag):
            try container.encode(tag, forKey: .tag)
        }
    }
}
