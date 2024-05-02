/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

struct FeatureFlagInfo: Decodable, Equatable {
    /**
     * Unique id of the flag, a UUID
     */
    let id: String

    /**
     * Date of the object's creation
     */
    let created: Date

    /**
     * Date of the last update to the flag definition
     */
    let lastUpdated: Date

    /**
     * The flag name
     */
    let name: String

    /**
     * The flag name
     */
    let reportingMetadata: AirshipJSON

    /**
      * Optional audience selector
      */
    let audienceSelector: DeviceAudienceSelector?

    /**
     * Optional time span in which the flag should be active
     */
    let timeCriteria: AirshipTimeCriteria?

    /**
     * Flag payload
     */
    let flagPayload: FeatureFlagPayload

    /**
     * Evaluation options.
     */
    let evaluationOptions: EvaluationOptions?

    private enum FeatureFlagObjectCodingKeys: String, CodingKey {
        case id = "flag_id"
        case created
        case lastUpdated = "last_updated"
        case flagPayload = "flag"
    }

    private enum FlagPayloadKeys: String, CodingKey {
        case type
        case reportingMetadata = "reporting_metadata"
        case audienceSelector = "audience_selector"
        case timeCriteria = "time_criteria"
        case variables
        case evaluationOptions = "evaluation_options"
        case name
    }

    init(id: String, created: Date, lastUpdated: Date, name: String, reportingMetadata: AirshipJSON, audienceSelector: DeviceAudienceSelector? = nil, timeCriteria: AirshipTimeCriteria? = nil, flagPayload: FeatureFlagPayload, evaluationOptions: EvaluationOptions? = nil) {
        self.id = id
        self.created = created
        self.lastUpdated = lastUpdated
        self.name = name
        self.reportingMetadata = reportingMetadata
        self.audienceSelector = audienceSelector
        self.timeCriteria = timeCriteria
        self.flagPayload = flagPayload
        self.evaluationOptions = evaluationOptions
    }


    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FeatureFlagObjectCodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)

        guard let created = AirshipDateFormatter.date(fromISOString: try container.decode(String.self, forKey: .created)) else {
            throw DecodingError.typeMismatch(
                FeatureFlagInfo.self,
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Invalid created date string.",
                    underlyingError: nil
                )
            )
        }
        self.created = created

        guard let lastUpdated = AirshipDateFormatter.date(fromISOString: try container.decode(String.self, forKey: .lastUpdated)) else {
            throw DecodingError.typeMismatch(
                FeatureFlagInfo.self,
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Invalid updated date string.",
                    underlyingError: nil
                )
            )
        }
        self.lastUpdated = lastUpdated


        self.flagPayload = try container.decode(FeatureFlagPayload.self, forKey: .flagPayload)

        let payloadContainer = try container.nestedContainer(keyedBy: FlagPayloadKeys.self, forKey: .flagPayload)

        self.name = try payloadContainer.decode(String.self, forKey: .name)
        self.audienceSelector = try payloadContainer.decodeIfPresent(DeviceAudienceSelector.self, forKey: .audienceSelector)
        self.timeCriteria = try payloadContainer.decodeIfPresent(AirshipTimeCriteria.self, forKey: .timeCriteria)
        self.reportingMetadata = try payloadContainer.decode(AirshipJSON.self, forKey: .reportingMetadata)
        self.evaluationOptions = try payloadContainer.decodeIfPresent(EvaluationOptions.self, forKey: .evaluationOptions)
    }
}

struct EvaluationOptions: Decodable, Equatable {
    let disallowStaleValue: Bool?
    let ttlMS: UInt64?

    init(disallowStaleValue: Bool? = nil, ttlMS: UInt64? = nil) {
        self.disallowStaleValue = disallowStaleValue
        self.ttlMS = ttlMS
    }

    enum CodingKeys: String, CodingKey {
        case disallowStaleValue = "disallow_stale_value"
        case ttlMS = "ttl"
    }
}

enum FeatureFlagPayload: Decodable, Equatable {
    case staticPayload(StaticInfo)
    case deferredPayload(DeferredInfo)

    struct DeferredInfo: Decodable, Equatable {
        let deferred: Deferred
    }

    struct Deferred: Decodable, Equatable {
        let url: URL

        enum CodingKeys: String, CodingKey {
            case url
        }
    }

    struct StaticInfo: Decodable, Equatable {
        let variables: FeatureFlagVariables?
    }

    private enum CodingKeys: CodingKey {
        case type
    }

    private enum FeatureFlagPayloadType: String, Decodable {
        case staticType = "static"
        case deferredType = "deferred"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(FeatureFlagPayloadType.self, forKey: .type)
        let singleValueContainer = try decoder.singleValueContainer()

        switch type {
        case .staticType:
            self = .staticPayload(
                try singleValueContainer.decode(StaticInfo.self)
            )
        case .deferredType:
            self = .deferredPayload(
                try singleValueContainer.decode(DeferredInfo.self)
            )
        }
    }
}

enum FeatureFlagVariables: Codable, Equatable {
    case fixed(AirshipJSON?)
    case variant([VariablesVariant])


    struct VariablesVariant: Codable, Equatable {
        let id: String
        let audienceSelector: DeviceAudienceSelector?
        let reportingMetadata: AirshipJSON
        let data: AirshipJSON?

        enum CodingKeys: String, CodingKey {
            case id
            case audienceSelector = "audience_selector"
            case reportingMetadata = "reporting_metadata"
            case data
        }
    }

    private enum FeatureFlagVariableType: String, Codable {
        case fixed
        case variant
    }

    private enum CodingKeys: CodingKey {
        case type
        case variants
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(FeatureFlagVariableType.self, forKey: .type)

        switch type {
        case .fixed:
            self = .fixed(
                try container.decodeIfPresent(AirshipJSON.self, forKey: .data)
            )
        case .variant:
            self = .variant(
                try container.decode([VariablesVariant].self, forKey: .variants)
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .fixed(let data):
            try container.encode(FeatureFlagVariableType.fixed, forKey: .type)
            try container.encodeIfPresent(data, forKey: .data)
        case .variant(let variants):
            try container.encode(FeatureFlagVariableType.variant, forKey: .type)
            try container.encode(variants, forKey: .variants)
        }
    }
}


extension FeatureFlagInfo {
    var isDeferred: Bool {
        if case .deferredPayload(_) = self.flagPayload {
            return true
        }
        return false
    }
}
