/* Copyright Airship and Contributors */

/// Compound audience selector
public indirect enum CompoundDeviceAudienceSelector: Sendable, Codable, Equatable {
    /// Atomic selector. Defines an actual audience selector.
    case atomic(DeviceAudienceSelector)

    /// NOT selector. Negates the results.
    case not(CompoundDeviceAudienceSelector)

    /// AND selector. All selectors have to evaluate true to match. If empty, evaluates to true.
    case and([CompoundDeviceAudienceSelector])

    /// OR selector. At least once selector has to evaluate true to match. If empty, evaluates to false.
    case or([CompoundDeviceAudienceSelector])

    enum CodingKeys: String, CodingKey {
        case type
        case audience
        case selector
        case selectors
    }
    
    private enum SelectorType: String, RawRepresentable, Codable {
        case atomic
        case not
        case and
        case or
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(SelectorType.self, forKey: .type)
        switch type {
        case .atomic:
            self = .atomic(try container.decode(DeviceAudienceSelector.self, forKey: .audience))
        case .not:
            self = .not(try container.decode(CompoundDeviceAudienceSelector.self, forKey: .selector))
        case .and:
            self = .and(try container.decode([CompoundDeviceAudienceSelector].self, forKey: .selectors))
        case .or:
            self = .or(try container.decode([CompoundDeviceAudienceSelector].self, forKey: .selectors))
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .atomic(let content):
            try container.encode(SelectorType.atomic, forKey: .type)
            try container.encode(content, forKey: .audience)
        case .not(let content):
            try container.encode(SelectorType.not, forKey: .type)
            try container.encode(content, forKey: .selector)
        case .and(let content):
            try container.encode(SelectorType.and, forKey: .type)
            try container.encode(content, forKey: .selectors)
        case .or(let content):
            try container.encode(SelectorType.or, forKey: .type)
            try container.encode(content, forKey: .selectors)
        }
    }
}

public extension CompoundDeviceAudienceSelector {
    /// Combines old and new selector into a CompoundDeviceAudienceSelector
    /// - Parameters:
    ///     - compoundSelector: An optional `CompoundDeviceAudienceSelector`.
    ///     - deviceSelector: An optional `DeviceAudienceSelector`.
    /// - Returns: A `CompoundDeviceAudienceSelector` if either provided selector
    ///  is non nill, otherwise nil.
    static func combine(
        compoundSelector: CompoundDeviceAudienceSelector?,
        deviceSelector: DeviceAudienceSelector?
    ) -> CompoundDeviceAudienceSelector? {
        if let compoundSelector, let deviceSelector {
            return .and([.atomic(deviceSelector), compoundSelector])
        } else if let compoundSelector {
            return compoundSelector
        } else if let deviceSelector {
            return .atomic(deviceSelector)
        }

        return nil
    }
}
