/* Copyright Airship and Contributors */



/// Schedule prepare result
enum SchedulePrepareResult: Sendable, CustomStringConvertible {
    case prepared(PreparedSchedule)
    case cancel
    case invalidate
    case skip
    case penalize

    var description: String {
        switch(self) {
        case .prepared: "prepared"
        case .cancel: "cancel"
        case .invalidate: "invalidate"
        case .skip: "skip"
        case .penalize: "penalize"
        }
    }
}
