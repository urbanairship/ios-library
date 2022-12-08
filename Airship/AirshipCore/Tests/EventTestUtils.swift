import Foundation

@testable
import AirshipCore

extension AirshipEventData: Equatable {
    public static func == (lhs: AirshipEventData, rhs: AirshipEventData) -> Bool {
        guard lhs.id == rhs.id,
              lhs.date == rhs.date,
              lhs.sessionID == rhs.sessionID,
              lhs.type == rhs.type,
              lhs.body as NSDictionary == rhs.body as NSDictionary
        else {
            return false
        }

        return true
    }

    static func makeTestData() -> AirshipEventData {
        return AirshipEventData(
            body: ["cool": "story"],
            id: UUID().uuidString,
            date: Date(),
            sessionID: UUID().uuidString,
            type: UUID().uuidString
        )
    }
}

