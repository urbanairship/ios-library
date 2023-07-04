/* Copyright Airship and Contributors */

import Foundation

enum ExperimentType: String, Codable, Sendable {
    case holdoutGroup = "Holdout"
}

enum ResultionType: String, Codable, Sendable {
    case `static` = "Static"
}

struct Experiment: Codable, Sendable {
    let id: String
    let type: ExperimentType
    let resolutionType: ResultionType
    let lastUpdated: Date
    let created: Date
    let reportingMetadata: AirshipJSON
    let audienceSelector: DeviceAudienceSelector
    let exclusions: [MessageCriteria]
    
    enum CodingKeys: String, CodingKey {
        case id
        case type = "experimentType"
        case resolutionType = "type"
        case lastUpdated = "last_updated"
        case created
        case reportingMetadata = "reporting_metadata"
        case audienceSelector = "audience_selector"
        case exclusions = "message_exclusions"
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
    
    private static let decoder: JSONDecoder = {
        var decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
