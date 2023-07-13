/* Copyright Airship and Contributors */

import Foundation

enum ExperimentType: String, Codable, Sendable, Equatable {
    case holdoutGroup = "holdout"
}

enum ResultionType: String, Codable, Sendable, Equatable {
    case `static` = "static"
}


struct TimeCriteria: Codable, Sendable, Equatable {
    let start: Int64?
    let end: Int64?

    enum CodingKeys: String, CodingKey {
        case start = "start_timestamp"
        case end = "end_timestamp"
    }
}

struct Experiment: Codable, Sendable, Equatable {
    let id: String
    let type: ExperimentType
    let resolutionType: ResultionType
    let lastUpdated: Date
    let created: Date
    let reportingMetadata: AirshipJSON
    let audienceSelector: DeviceAudienceSelector
    let exclusions: [MessageCriteria]?
    let timeCriteria: TimeCriteria?

    enum CodingKeys: String, CodingKey {
        case id = "experiment_id"
        case created
        case lastUpdated = "last_updated"
        case experimentDefinition = "experiment_definition"
    }
    
    enum ExperimentDefinitionKeys: String, CodingKey {
        case type = "experiment_type"
        case resolutionType = "type"
        case reportingMetadata = "reporting_metadata"
        case audienceSelector = "audience_selector"
        case exclusions = "message_exclusions"
        case timeCriteria = "time_criteria"
    }

    init(
        id: String,
        type: ExperimentType = .holdoutGroup,
        resolutionType: ResultionType = ResultionType.static,
        lastUpdated: Date,
        created: Date,
        reportingMetadata: AirshipJSON,
        audienceSelector: DeviceAudienceSelector,
        exclusions: [MessageCriteria]? = nil,
        timeCriteria: TimeCriteria? = nil
    ) {
        self.id = id
        self.type = type
        self.resolutionType = resolutionType
        self.lastUpdated = lastUpdated
        self.created = created
        self.reportingMetadata = reportingMetadata
        self.audienceSelector = audienceSelector
        self.exclusions = exclusions
        self.timeCriteria = timeCriteria
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.created = try container.decode(Date.self, forKey: .created)
        self.lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)

        let definitionContainer = try container.nestedContainer(keyedBy: ExperimentDefinitionKeys.self, forKey: .experimentDefinition)
        self.type = try definitionContainer.decode(ExperimentType.self, forKey: .type)
        self.resolutionType = try definitionContainer.decode(ResultionType.self, forKey: .resolutionType)
        self.reportingMetadata = try definitionContainer.decode(AirshipJSON.self, forKey: .reportingMetadata)
        self.audienceSelector = try definitionContainer.decode(DeviceAudienceSelector.self, forKey: .audienceSelector)
        self.exclusions = try definitionContainer.decodeIfPresent([MessageCriteria].self, forKey: .exclusions)
        self.timeCriteria = try definitionContainer.decodeIfPresent(TimeCriteria.self, forKey: .timeCriteria)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        
        try container.encode(Self.dateFormatter.string(from: self.created), forKey: .created)
        try container.encode(Self.dateFormatter.string(from: self.lastUpdated), forKey: .lastUpdated)
        
        var definition = container.nestedContainer(keyedBy: ExperimentDefinitionKeys.self, forKey: .experimentDefinition)
        try definition.encode(self.type, forKey: .type)
        try definition.encode(self.resolutionType, forKey: .resolutionType)
        try definition.encode(self.reportingMetadata, forKey: .reportingMetadata)
        try definition.encode(self.audienceSelector, forKey: .audienceSelector)
        try definition.encodeIfPresent(self.exclusions, forKey: .exclusions)
        try definition.encodeIfPresent(self.timeCriteria, forKey: .timeCriteria)
    }
    
    static func from(json: [AnyHashable: Any]) -> Experiment? {
        guard !json.isEmpty else { return nil }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: json)
            return try Self.decoder.decode(Self.self, from: data)
        } catch {
            AirshipLogger.error("Failed to parse experiment from \(json): \(error)")
            return nil
        }
    }
    
    private static let dateFormatter: DateFormatter = {
        let result = DateFormatter()
        result.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        return result
    }()
    
    private static let decoder: JSONDecoder = {
        var decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(Self.dateFormatter)
        return decoder
    }()
}

