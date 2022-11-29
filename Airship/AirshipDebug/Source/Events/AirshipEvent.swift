/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

/// A wrapper for representing an Airship event in the Debug UI
struct AirshipEvent: Equatable, Hashable {
    var identifier: String
    var type: String
    var date: Date
    var body: String
}
