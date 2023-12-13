/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif


@objc(UAFrequencyLimitManagerProtocol)
public protocol FrequencyLimitManagerProtocol: Sendable {
    @MainActor
    func getFrequencyChecker(
        constraintIDs: [String]
    ) async throws -> FrequencyCheckerProtocol?

    // Temp method until we have the updated in swift
    func setConstraints(data: Data) async throws
}

@objc(UAFrequencyLimitManager)
public final class FrequencyLimitManager: NSObject, FrequencyLimitManagerProtocol, @unchecked Sendable {
    private let frequencyLimitStore: FrequencyLimitStore
    private let date: AirshipDateProtocol
    private let storeQueue: AirshipSerialQueue
    private var checkers: [() -> FrequencyChecker?] = []
    private var pendingOccurrences: Set<Occurrence> = Set()

    init(
        dataStore: FrequencyLimitStore,
        date: AirshipDateProtocol = AirshipDate(),
        storeQueue: AirshipSerialQueue = AirshipSerialQueue()
    ) {
        self.frequencyLimitStore = dataStore
        self.date = date
        self.storeQueue = storeQueue
    }
    
    @objc
    public convenience init(config: RuntimeConfig) {
        self.init(dataStore: FrequencyLimitStore(config: config))
    }

    @MainActor
    @objc
    public func getFrequencyChecker(
        constraintIDs: [String]
    ) async throws -> FrequencyCheckerProtocol? {
        self.checkers.removeAll { checkerBlock in
            checkerBlock() == nil
        }

        guard !constraintIDs.isEmpty else {
            return nil
        }

        let checker: FrequencyChecker? = try await storeQueue.run {
            let constraintInfos = try await self.frequencyLimitStore.fetchConstraints(constraintIDs)
            if (constraintInfos.isEmpty) {
                return nil
            }

            return FrequencyChecker(
                constraintInfos: constraintInfos,
                date: self.date
            ) { date in
                self.recordOccurrence(date: date, constraintIDs: constraintIDs)
            }
        }

        if let checker = checker {
            checker.newOccurrences(pendingOccurrences)

            self.checkers.append(
                { [weak checker] in checker }
            )
        }

        return checker
    }

    @objc
    public func setConstraints(data: Data) async throws {
        let constraints = try AirshipJSON.defaultDecoder.decode(
            [FrequencyConstraint].self,
            from: data
        )
        try await setConstraints(constraints)
    }

    func setConstraints(_ constraints: [FrequencyConstraint]) async throws {

        try await self.storeQueue.run {
            await self.actuallyWritePending()
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

            for upsert in upsert {
                try await self.frequencyLimitStore.upsertConstraint(upsert)
            }

        }
    }

    func upsertConstraint(_ constraint: FrequencyConstraint) async throws {
        try await self.storeQueue.run {
            await self.actuallyWritePending()
            try await self.frequencyLimitStore.upsertConstraint(constraint)
        }
    }

    func removeConstraint(_ constraint: FrequencyConstraint) async throws {
        try await self.storeQueue.run {
            await self.actuallyWritePending()
            try await self.frequencyLimitStore.deleteConstraints([constraint.identifier])
        }
    }

    func removeConstraint(constraintID: String) async throws {
        try await self.storeQueue.run {
            await self.actuallyWritePending()
            try await self.frequencyLimitStore.deleteConstraints([constraintID])
        }
    }
    
    @MainActor
    private func recordOccurrence(date: Date, constraintIDs: [String]) {
        let occurrences = constraintIDs.map { constraintID in
            Occurrence(
                constraintID: constraintID,
                timestamp: date
            )
        }

        self.checkers.forEach { checkerBlock in
            checkerBlock()?.newOccurrences(Set(occurrences))
        }

        self.pendingOccurrences.formUnion(occurrences)

        Task { @MainActor in
            await writePending()
        }
    }

    func writePending() async {
        await self.storeQueue.runSafe {
            await self.actuallyWritePending()
        }
    }

    private func actuallyWritePending() async {
        let pending = await self.popPendingOccurrences()
        guard !pending.isEmpty else {
            return
        }
        do {
            try await self.frequencyLimitStore.saveOccurrences(pending)
        } catch {
            AirshipLogger.error("Unable to save occurrences: \(pending)")
        }
    }
    @MainActor
    private func popPendingOccurrences() -> Set<Occurrence> {
        let pending = self.pendingOccurrences
        self.pendingOccurrences.removeAll()
        return pending
    }
}

