/* Copyright Airship and Contributors */

import Foundation

/// An update to a live activity
struct LiveActivityUpdate: Codable, Equatable {
    enum Action: String, Codable {
        case set
        case remove
    }
    
    enum Source: Equatable {
        enum TokenType: String, Codable {
            case start = "start_token"
            case update = "update_token"
        }
        
        case liveActivity(id: String, name: String, startTimeMS: Int64)
        case startToken(attributeType: String)
    }

    /// Update action
    var action: Action
    
    /// Update source
    let source: Source

    /// The token, should be available on a set
    var token: String?

    /// The update start time in milliseconds
    var actionTimeMS: Int64

    enum CodingKeys: String, CodingKey {
        case action = "action"
        case id = "id"
        case name = "name"
        case token = "token"
        case actionTimeMS = "action_ts_ms"
        case startTimeMS = "start_ts_ms"
        case type = "type"
        case attributeType = "attributes_type"
    }
    
    init(action: Action,
         source: Source,
         actionTimeMS: Int64,
         token: String? = nil
    ) {
        self.action = action
        self.source = source
        self.token = token
        self.actionTimeMS = actionTimeMS
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let type: Source.TokenType
        if container.contains(.type) {
            type = try container.decode(Source.TokenType.self, forKey: .type)
        } else {
            type = .update
        }
        
        switch type {
        case .start:
            self.source = .startToken(attributeType: try container.decode(String.self, forKey: .attributeType))
        case .update:
            self.source = .liveActivity(
                id: try container.decode(String.self, forKey: .id),
                name: try container.decode(String.self, forKey: .name),
                startTimeMS: try container.decode(Int64.self, forKey: .startTimeMS))
        }
        
        self.action = try container.decode(Action.self, forKey: .action)
        self.token = try container.decodeIfPresent(String.self, forKey: .token)
        self.actionTimeMS = try container.decode(Int64.self, forKey: .actionTimeMS)
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(action, forKey: .action)
        try container.encodeIfPresent(token, forKey: .token)
        try container.encode(actionTimeMS, forKey: .actionTimeMS)
        
        switch source {
        case .liveActivity(let id, let name, let startTimeMS):
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(startTimeMS, forKey: .startTimeMS)
            try container.encode(Source.TokenType.update, forKey: .type)
        case .startToken(let attributeType):
            try container.encode(attributeType, forKey: .attributeType)
            try container.encode(Source.TokenType.start, forKey: .type)
        }
    }
}

