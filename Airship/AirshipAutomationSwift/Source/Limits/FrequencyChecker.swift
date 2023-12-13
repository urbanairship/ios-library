/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#endif

@objc(UAFrequencyChecker)
public protocol FrequencyCheckerProtocol: Sendable {
    @MainActor
    var isOverLimit: Bool { get }
    @MainActor
    func checkAndIncrement() -> Bool
}

final class FrequencyChecker: FrequencyCheckerProtocol, @unchecked Sendable {

    private let constraintInfos: [ConstraintInfo]
    private var occurenceMap: [String: Set<Occurrence>]

    private let onIncrement: @Sendable @MainActor (Date) -> Void
    private let date: AirshipDateProtocol

    init(
        constraintInfos: [ConstraintInfo],
        date: AirshipDateProtocol,
        onIncrement: @MainActor @Sendable @escaping (Date) -> Void
    ) {
        self.constraintInfos = constraintInfos
        self.date = date
        self.onIncrement = onIncrement
        self.occurenceMap = [:]
        self.constraintInfos.forEach { info in
            occurenceMap[info.constraint.identifier] = Set(info.occurrences)
        }
    }

    /// Checks if the frequency constraints are over the limit.
    /// - Returns `true` if the frequency constraints are over the limit, `flase` otherwise.
    @MainActor
    var isOverLimit: Bool {
        return self.constraintInfos.contains { info in
            isOverLimit(constraintInfo: info)
        }
    }

    /// Checks if the frequency constraints are over the limit before incrementing the count towards the constraints.
    /// - Returns `true` if the constraints are not over the limit and the count was incremented, `flase` otherwise.
    @MainActor
    func checkAndIncrement() -> Bool {
        if (isOverLimit) {
            return false
        }

        self.onIncrement(self.date.now)
        return true
    }

    @MainActor
    private func isOverLimit(
        constraintInfo: ConstraintInfo
    ) -> Bool {
        let occurrences = self.occurenceMap[constraintInfo.constraint.identifier]?.sorted { l, r in
            l.timestamp <= r.timestamp
        } ?? []

        let constraint = constraintInfo.constraint

        if (occurrences.count < constraint.count) {
            return false
        }

        let timeStamp = occurrences[occurrences.count - Int(constraint.count)].timestamp
        let timeSinceOccurrence = self.date.now.timeIntervalSince(timeStamp)
        return timeSinceOccurrence <= constraint.range
    }

    @MainActor
    func newOccurrences(_ occurrences: Set<Occurrence>) {
        occurrences.forEach { occurrence in
            self.occurenceMap[occurrence.constraintID]?.insert(occurrence)
        }
    }
}
