/* Copyright Airship and Contributors */

import Foundation

@preconcurrency
import Combine

#if canImport(AirshipCore)
import AirshipCore
#endif

protocol AutomationRemoteDataSubscriberProtocol: Sendable {
    @MainActor
    func subscribe()

    @MainActor
    func unsubscribe()
}

final class AutomationRemoteDataSubscriber: AutomationRemoteDataSubscriberProtocol, @unchecked Sendable {
    private let sourceInfoStore: AutomationSourceInfoStore
    private let remoteDataAccess: AutomationRemoteDataAccessProtocol
    private let engine: AutomationEngineProtocol
    private let frequencyLimitManager: FrequencyLimitManagerProtocol
    private let airshipSDKVersion: String

    @MainActor
    private var processTask: Task<Void, Never>?

    private var updateStream: AsyncStream<InAppRemoteData> {
        AsyncStream { continuation in
            let cancellable = self.remoteDataAccess.publisher.sink { continuation.yield($0) }
            continuation.onTermination = { continuation in
                cancellable.cancel()
            }
        }
    }

    init(
        dataStore: PreferenceDataStore,
        remoteDataAccess: AutomationRemoteDataAccessProtocol,
        engine: AutomationEngineProtocol,
        frequencyLimitManager: FrequencyLimitManagerProtocol,
        airshipSDKVersion: String = AirshipVersion.version
    ) {
        self.sourceInfoStore = AutomationSourceInfoStore(dataStore: dataStore)
        self.remoteDataAccess = remoteDataAccess
        self.engine = engine
        self.frequencyLimitManager = frequencyLimitManager
        self.airshipSDKVersion = airshipSDKVersion
    }

    @MainActor
    func subscribe() {
        if (processTask != nil) {
            return
        }

        let stream = self.updateStream
        self.processTask = Task { [weak self] in
            for await update in stream {
                guard !Task.isCancelled else {
                    return
                }

                await self?.processConstraints(update)
                await self?.processAutomations(update)
            }
        }
    }

    @MainActor
    func unsubscribe() {
        processTask?.cancel()
        processTask = nil
    }

    private func processAutomations(_ data: InAppRemoteData) async {
        var currentSchedules: [AutomationSchedule]!

        do {
            currentSchedules = try await engine.schedules
        } catch {
            AirshipLogger.error("Unable to process automations. Failed to query current schedules with error \(error)")
            return
        }

        for source in RemoteDataSource.allCases {
            let schedules = currentSchedules.filter { schedule in
                self.remoteDataAccess.source(forSchedule: schedule) == source
            }

            do {
                try await self.syncAutomations(
                    payload: data.payloads[source],
                    source: source,
                    currentSchedules: schedules
                )
            } catch {
                AirshipLogger.error("Failed to process \(source) automations \(error)")
            }
        }
    }

    private func syncAutomations(
        payload: InAppRemoteData.Payload?,
        source: RemoteDataSource,
        currentSchedules: [AutomationSchedule]
    ) async throws {

        let currentScheduleIDs = currentSchedules.map { $0.identifier }

        guard
            let payload = payload
        else {
            if !currentSchedules.isEmpty {
                try await engine.stopSchedules(
                    identifiers: currentScheduleIDs
                )
            }
            return
        }

        let contactID = payload.remoteDataInfo?.contactID
        let lastSourceInfo = self.sourceInfoStore.getSourceInfo(
            source: source,
            contactID: contactID
        )

        let currentSourceInfo = AutomationSourceInfo(
            remoteDataInfo: payload.remoteDataInfo,
            payloadTimestamp: payload.timestamp,
            airshipSDKVersion: airshipSDKVersion
        )

        guard lastSourceInfo != currentSourceInfo else {
            return
        }

        let identifiers = Set(payload.data.schedules.map { $0.identifier })

        let schedulesToStop = currentSchedules.filter { !identifiers.contains($0.identifier) }
        if !schedulesToStop.isEmpty {
            try await engine.stopSchedules(
                identifiers: schedulesToStop.map { $0.identifier }
            )
        }

        let schedulesToUpsert = payload.data.schedules.filter { schedule in
            // If we have an ID for this schedule then its either unchanged or updated
            if (currentScheduleIDs.contains(schedule.identifier)) {
                return true
            }

            // Otherwise check to see if we consider this a new schedule based on timestamp
            // and SDK version
            return schedule.isNewSchedule(
                sinceDate: lastSourceInfo?.payloadTimestamp ?? .distantPast,
                lastSDKVersion: lastSourceInfo?.airshipSDKVersion
            )
        }

        if !schedulesToUpsert.isEmpty {
            try await engine.upsertSchedules(schedulesToUpsert)
        }

        self.sourceInfoStore.setSourceInfo(
            currentSourceInfo,
            source: source,
            contactID: contactID
        )
    }

    private func processConstraints(_ data: InAppRemoteData) async {
        let constraints = RemoteDataSource.allCases
            .compactMap { source in
                data.payloads[source]?.data.constraints
            }
            .reduce([], +)

        do {
            try await frequencyLimitManager.setConstraints(constraints)
        } catch {
            AirshipLogger.error("Failed to process constraints \(error)")
        }
    }
}
