/* Copyright Airship and Contributors */



/// Schedule ready result
enum ScheduleReadyResult: Sendable {
    case ready
    case invalidate
    case notReady
    case skip
}
