/* Copyright Airship and Contributors */

import Foundation

/**
 * Chat conversation routing data.
 */
@objc(UAChatRouting)
public class ChatRouting : NSObject, Codable {
    /**
     * Value for routing a conversation to a specific agent.
     */
    let agent: String
    
    enum CodingKeys: String, CodingKey {
        case agent = "agent"
    }
    
    /**
     * Default constructor
     * @param agent The agent.
     */
    @objc
    public init(agent: String) {
        self.agent = agent
    }
}
