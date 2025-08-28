/* Copyright Airship and Contributors */



struct Occurrence: Sendable, Equatable, Hashable {
    let constraintID: String
    let timestamp: Date
}
