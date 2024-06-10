import Foundation

@testable
import AirshipCore

extension AirshipEventData {
   
    static func makeTestData(type: EventType = .appInit) -> AirshipEventData {
        return AirshipEventData(
            body: try! AirshipJSON.wrap(["cool": "story"]),
            id: UUID().uuidString,
            date: Date(),
            sessionID: UUID().uuidString,
            type: type
        )
    }
}

