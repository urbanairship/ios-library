/* Copyright Airship and Contributors */

import Foundation

/// Represents the possible sites.
public enum CloudSite: String, Sendable, Decodable {
    /// Represents the US cloud site. This is the default value.
    /// Projects available at go.airship.com must use this value.
    case us
    /// Represents the EU cloud site.
    /// Projects available at go.airship.eu must use this value.
    case eu
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        do {
            let stringValue = try container.decode(String.self)
            switch(stringValue.lowercased()) {
            case "us":
                self = .us
            case "eu":
                self = .eu
            default:
                self = .us
            }
        } catch {
            guard let intValue = try? container.decode(Int.self) else {
                throw error
            }
            
            switch(intValue) {
                
            case 0:
                self = .us
            case 1:
                self = .eu
            default:
                throw error
            }
        }
    }
}
