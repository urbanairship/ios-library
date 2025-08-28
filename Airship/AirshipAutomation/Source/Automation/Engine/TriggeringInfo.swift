/* Copyright Airship and Contributors */



#if canImport(AirshipCore)
import AirshipCore
#endif

struct TriggeringInfo: Equatable, Sendable, Codable {
    var context: AirshipTriggerContext?
    var date: Date
}
