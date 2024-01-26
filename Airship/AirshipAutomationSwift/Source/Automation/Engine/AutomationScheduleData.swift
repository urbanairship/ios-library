/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#endif

import Foundation

struct AutomationScheduleData: Sendable, Equatable {
    var identifier: String
    var group: String?
    var startDate: Date
    var endDate: Date
    var schedule: AutomationSchedule

    var scheduleState: AutomationScheduleState
    var scheduleStateChangeDate: Date
    var executionCount: UInt = 0
    var triggerInfo: TriggeringInfo?
    var preparedScheduleInfo: PreparedScheduleInfo?
}

extension AutomationScheduleData {
    func isInState(_ state: [AutomationScheduleState]) -> Bool {
        return state.contains(self.scheduleState)
    }

    func isActive(date: Date) -> Bool {
        return !self.isExpired(date: date) && self.startDate >= date
    }

    func isExpired(date: Date) -> Bool {
        return self.endDate <= date
    }

    var isOverLimit: Bool {
        return (self.schedule.limit ?? 1) <= self.executionCount
    }

    private mutating func setState(_ state: AutomationScheduleState, date: Date) {
        guard scheduleState != state else { return }
        self.scheduleState = state
        self.scheduleStateChangeDate = date
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

    mutating func attempRehabilitateSchedule(date: Date) {
        if isOverLimit || isExpired(date: date) {
            if isInState([.idle, .paused]) {
                finished(date: date)
            }
        } else if isInState([.finished]) {
            self.idle(date: date)
        }
    }

    mutating func prepareSkipped(date: Date, penalize: Bool) {
        guard self.isInState([.triggered]) else {
            return
        }

        if (penalize) {
            self.executionCount += 1
        }

        if isOverLimit || isExpired(date: date) {
            finished(date: date)
        } else {
            idle(date: date)
        }
    }

    mutating func prepareInterrupted(date: Date) {
        guard self.isInState([.prepared, .triggered]) else {
            return
        }

        guard !isOverLimit, !isExpired(date: date) else {
            finished(date: date)
            return
        }

        if self.scheduleState != .triggered {
            self.scheduleState = .triggered
            self.scheduleStateChangeDate = date
        }
    }

    mutating func prepareCancelled(date: Date) {
        guard self.isInState([.prepared, .triggered]) else {
            return
        }

        if isOverLimit || isExpired(date: date) {
            finished(date: date)
        } else {
            idle(date: date)
        }
    }

    mutating func prepared(info: PreparedScheduleInfo, date: Date) {
        guard self.isInState([.triggered]) else {
            return
        }

        guard !isOverLimit, !isExpired(date: date) else {
            finished(date: date)
            return
        }

        self.scheduleState = .prepared
        self.preparedScheduleInfo = info
    }

    mutating func executionSkipped(date: Date) {
        guard self.isInState([.prepared]) else {
            return
        }

        if isOverLimit || isExpired(date: date) {
            finished(date: date)
        } else if self.schedule.interval != nil {
            paused(date: date)
        } else {
            idle(date: date)
        }
    }

    mutating func executionInvalidated(date: Date) {
        guard self.isInState([.prepared]) else {
            return
        }

        if isOverLimit || isExpired(date: date) {
            finished(date: date)
        } else {
            self.preparedScheduleInfo = nil
        }
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
            self.scheduleState = .triggered
            self.scheduleStateChangeDate = date
            prepareInterrupted(date: date)
        } else {
            finishedExecuting(date: date)
        }
    }


    mutating func finishedExecuting(date: Date) {
        guard self.isInState([.executing]) else {
            return
        }

        self.executionCount += 1

        if isOverLimit || isExpired(date: date) {
            finished(date: date)
        } else if self.schedule.interval != nil {
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
        triggerContext: AirshipTriggerContext?,
        date: Date
    ) {
        guard self.scheduleState == .idle else {
            return
        }

        guard !isOverLimit, !isExpired(date: date) else {
            self.finished(date: date)
            return
        }

        self.scheduleStateChangeDate = date
        self.preparedScheduleInfo = nil
        self.triggerInfo = TriggeringInfo(context: triggerContext, date: date)
        self.scheduleState = .triggered
    }
}
