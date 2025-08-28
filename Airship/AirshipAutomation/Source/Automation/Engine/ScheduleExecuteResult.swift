/* Copyright Airship and Contributors */



/// Schedule execute result
enum ScheduleExecuteResult: Sendable {
    case cancel
    case finished
    case retry
}
