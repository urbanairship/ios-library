/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#endif

import Foundation

struct AutomationScheduleData: Sendable, Equatable, CustomDebugStringConvertible {
    var schedule: AutomationSchedule
    var scheduleState: AutomationScheduleState
    var lastScheduleModifiedDate: Date
    var scheduleStateChangeDate: Date
    var executionCount: Int
    var triggerInfo: TriggeringInfo?
    var preparedScheduleInfo: PreparedScheduleInfo?
    var associatedData: Data?
    var triggerSessionID: String

    var debugDescription: String {
        return "AutomationSchedule(id: \(schedule.identifier), state: \(scheduleState))"
    }
}

extension AutomationScheduleData {
    func isInState(_ state: [AutomationScheduleState]) -> Bool {
        return state.contains(self.scheduleState)
    }

    func isActive(date: Date) -> Bool {
        guard !self.isExpired(date: date) else { return false }
        guard let start = self.schedule.start else { return true }
        return date >= start
    }

    func isExpired(date: Date) -> Bool {
        guard let end = self.schedule.end else { return false }
        return end <= date
    }

    var isOverLimit: Bool {
        // 0 means no limit
        guard self.schedule.limit != 0 else { return false }
        return (self.schedule.limit ?? 1) <= self.executionCount
    }

    private mutating func setState(_ state: AutomationScheduleState, date: Date) {
        guard scheduleState != state else { return }
        self.scheduleState = state
        self.scheduleStateChangeDate = date
        self.lastScheduleModifiedDate = date
    }

    mutating func finished(date: Date) {
        self.setState(.finished, date: date)
        self.preparedScheduleInfo = nil
        self.triggerInfo = nil
    }

    mutating func idle(date: Date) {
        self.setState(.idle, date: date)
        self.preparedScheduleInfo = nil
        self.triggerInfo = nil
    }

    mutating func paused(date: Date) {
        self.setState(.paused, date: date)
        self.preparedScheduleInfo = nil
        self.triggerInfo = nil
    }

    mutating func updateState(date: Date) {
        if isOverLimit || isExpired(date: date) {
            finished(date: date)
        } else if isInState([.finished]) {
            self.idle(date: date)
        }
    }

    mutating func prepareCancelled(date: Date, penalize: Bool) {
        guard self.isInState([.triggered]) else {
            return
        }

        if (penalize) {
            self.executionCount += 1
        }

        guard !isOverLimit, !isExpired(date: date) else {
            finished(date: date)
            return
        }

        idle(date: date)
    }

    mutating func prepareInterrupted(date: Date) {
        guard self.isInState([.prepared, .triggered]) else {
            return
        }

        guard !isOverLimit, !isExpired(date: date) else {
            finished(date: date)
            return
        }

        setState(.triggered, date: date)
    }

    mutating func prepared(info: PreparedScheduleInfo, date: Date) {
        guard self.isInState([.triggered]) else {
            return
        }

        guard !isOverLimit, !isExpired(date: date) else {
            finished(date: date)
            return
        }

        self.preparedScheduleInfo = info
        self.setState(.prepared, date: date)
    }

    mutating func executionCancelled(date: Date) {
        guard self.isInState([.prepared]) else {
            return
        }

        guard !isOverLimit, !isExpired(date: date) else {
            finished(date: date)
            return
        }

        idle(date: date)
    }

    mutating func executionSkipped(date: Date) {
        guard self.isInState([.prepared]) else {
            return
        }

        guard !isOverLimit, !isExpired(date: date) else {
            finished(date: date)
            return
        }

        if self.schedule.interval != nil {
            paused(date: date)
        } else {
            idle(date: date)
        }
    }

    mutating func executionInvalidated(date: Date) {
        guard self.isInState([.prepared]) else {
            return
        }

        guard !isOverLimit, !isExpired(date: date) else {
            finished(date: date)
            return
        }

        self.preparedScheduleInfo = nil
        self.setState(.triggered, date: date)
    }

    mutating func executing(date: Date) {
        guard self.isInState([.prepared]) else {
            return
        }

        self.scheduleState = .executing
        self.scheduleStateChangeDate = date
    }

    mutating func executionInterrupted(date: Date, retry: Bool) {
        guard self.isInState([.executing]) else {
            return
        }

        if (retry) {
            guard !isOverLimit, !isExpired(date: date) else {
                finished(date: date)
                return
            }

            self.preparedScheduleInfo = nil
            self.setState(.triggered, date: date)
        } else {
            finishedExecuting(date: date)
        }
    }

    mutating func finishedExecuting(date: Date) {
        guard self.isInState([.executing]) else {
            return
        }

        self.executionCount += 1

        guard !isOverLimit, !isExpired(date: date) else {
            finished(date: date)
            return
        }

        if self.schedule.interval != nil {
            paused(date: date)
        } else {
            idle(date: date)
        }
    }

    func shouldDelete(date: Date) -> Bool {
        guard self.scheduleState == .finished else { return false }
        guard let editGracePeriod = self.schedule.editGracePeriodDays else {
            return true
        }

        let timeSinceFinished = date.timeIntervalSince(self.scheduleStateChangeDate)
        return timeSinceFinished >= Double(editGracePeriod * 86400) // days to seconds
    }

    mutating func triggered(
        triggerInfo: TriggeringInfo,
        date: Date
    ) {
        guard self.scheduleState == .idle else {
            return
        }

        guard !isOverLimit, !isExpired(date: date) else {
            self.finished(date: date)
            return
        }

        self.triggerSessionID = UUID().uuidString
        self.preparedScheduleInfo = nil
        self.triggerInfo = triggerInfo
        setState(.triggered, date: date)
    }
}
