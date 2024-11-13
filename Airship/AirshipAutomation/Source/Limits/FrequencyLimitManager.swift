/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Manager protocol for keeping track of frequency limits and occurrence counts.
protocol FrequencyLimitManagerProtocol: Sendable {

    /// Gets a frequency checker corresponding to the passed in constraints identifiers
    /// - Parameter constraintIDs: Constraint identifiers
    /// - Returns: The frequency checker instance
    @MainActor
    func getFrequencyChecker(
        constraintIDs: [String]?
    ) async throws -> any FrequencyCheckerProtocol

    func setConstraints(_ constraints: [FrequencyConstraint]) async throws
}

/// Manager for keeping track of frequency limits and occurrence counts.
final class FrequencyLimitManager: FrequencyLimitManagerProtocol, @unchecked Sendable {
    private let frequencyLimitStore: FrequencyLimitStore
    private let date: any AirshipDateProtocol
    private let storeQueue: AirshipSerialQueue

    private let emptyChecker = FrequencyChecker(
        isOverLimitBlock: { false },
        checkAndIncrementBlock: { true }
    )

    @MainActor
    private var fetchedConstraints: [String: ConstraintInfo] = [:]

    @MainActor
    private var pendingOccurrences: [Occurrence] = []

    init(
        dataStore: FrequencyLimitStore,
        date: any AirshipDateProtocol = AirshipDate(),
        storeQueue: AirshipSerialQueue = AirshipSerialQueue()
    ) {
        self.frequencyLimitStore = dataStore
        self.date = date
        self.storeQueue = storeQueue
    }
    
    convenience init(config: RuntimeConfig) {
        self.init(dataStore: FrequencyLimitStore(config: config))
    }

    @MainActor
    func getFrequencyChecker(
        constraintIDs: [String]?
    ) async throws -> any FrequencyCheckerProtocol {
        guard let constraintIDs = constraintIDs, !constraintIDs.isEmpty else {
            return emptyChecker
        }

        return try await storeQueue.run {
            await self.writePending()

            let fetched = await self.fetchedConstraints.keys
            let need = Set(constraintIDs).subtracting(fetched)

            if !need.isEmpty {
                let constraintInfos = try await self.frequencyLimitStore.fetchConstraints(
                    Array(need)
                )

                if (constraintInfos.count != need.count) {
                    let missing = need.subtracting(constraintInfos.map { $0.constraint.identifier } )
                    throw AirshipErrors.error("Requested constraints \(constraintIDs) missing: \(missing)")
                }

                await self.updateFetchedConstraintInfos(constraintInfos)
            }

            return FrequencyChecker(
                isOverLimitBlock: { [weak self] in
                    return self?.isOverLimit(constraintIDs: constraintIDs) ?? true
                },
                checkAndIncrementBlock: { [weak self] in
                    return self?.checkAndIncrement(constraintIDs: constraintIDs) ?? false
                }
            )
        }
    }

    func setConstraints(data: Data) async throws {
        let constraints = try AirshipJSON.defaultDecoder.decode(
            [FrequencyConstraint].self,
            from: data
        )
        try await setConstraints(constraints)
    }

    func setConstraints(_ constraints: [FrequencyConstraint]) async throws {
        try await self.storeQueue.run {
            await self.writePending()

            let existing = Set(
                try await self.frequencyLimitStore.fetchConstraints()
                    .map { $0.constraint }
            )

            let incomingIDs = Set(constraints.map { $0.identifier })

            let upsert = constraints.filter { constraint in
                !existing.contains(constraint)
            }

            let delete = existing
                .filter { constraint in
                    if (!incomingIDs.contains(constraint.identifier)) {
                        return true
                    }

                    return constraints.contains { incoming in
                        constraint.identifier == incoming.identifier &&
                        constraint.range != incoming.range
                    }
                }
                .map { $0.identifier }

            try await self.frequencyLimitStore.deleteConstraints(delete)
            await self.removeFetchedConstraints(delete)

            for upsert in upsert {
                try await self.frequencyLimitStore.upsertConstraint(upsert)
                await self.updateFetchedConstraint(upsert)
            }
        }
    }

    @MainActor
    private func isOverLimit(constraintIDs: [String]) -> Bool {
        return constraintIDs.contains(
            where: { constraintID in
                guard let constraintInfo = self.fetchedConstraints[constraintID] else {
                    return false
                }

                let constraint = constraintInfo.constraint
                let occurrences = constraintInfo.occurrences.sorted { l, r in
                    l.timestamp <= r.timestamp
                }

                guard occurrences.count >= constraint.count else { return false }

                let timeStamp = occurrences[occurrences.count - Int(constraint.count)].timestamp
                let timeSinceOccurrence = self.date.now.timeIntervalSince(timeStamp)
                return timeSinceOccurrence <= constraint.range
            }
        )
    }

    @MainActor
    private func checkAndIncrement(constraintIDs: [String]) -> Bool {
        guard !isOverLimit(constraintIDs: constraintIDs) else { return false }

        let now = self.date.now

        constraintIDs.forEach { constraintID in
            let occurrence = Occurrence(constraintID: constraintID, timestamp: now)
            self.fetchedConstraints[constraintID]?.occurrences.append(occurrence)
            self.pendingOccurrences.append(occurrence)
        }

        // Queue up a task to write pending
        Task {
            await self.storeQueue.runSafe {
                await self.writePending()
            }
        }

        return true
    }

    @MainActor
    private func updateFetchedConstraint(_ constraint: FrequencyConstraint) {
        self.fetchedConstraints[constraint.identifier]?.constraint = constraint
    }

    @MainActor
    private func removeFetchedConstraints(_ constraintIDs: [String]) {
        constraintIDs.forEach { constraintID in
            self.fetchedConstraints[constraintID] = nil
        }
    }

    @MainActor
    private func updateFetchedConstraintInfos(_ constraintInfos: [ConstraintInfo]) {
        constraintInfos.forEach { info in
            self.fetchedConstraints[info.constraint.identifier] = info
        }
    }

    func writePending() async {
        let pending = await popPendingOccurrences()
        do {
            try await self.frequencyLimitStore.saveOccurrences(pending)
        } catch {
            AirshipLogger.error("Failed to write pending: \(pending) \(error)")
            await appendPendingOccurrences(pending)
        }
    }

    @MainActor
    private func appendPendingOccurrences(_ pending: [Occurrence]) {
        self.pendingOccurrences.append(contentsOf: pending)
    }

    @MainActor
    private func popPendingOccurrences() -> [Occurrence] {
        let pending = self.pendingOccurrences
        self.pendingOccurrences = []
        return pending
    }
}
