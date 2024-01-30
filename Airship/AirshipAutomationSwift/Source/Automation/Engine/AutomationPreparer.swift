/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

protocol AutomationPreparerProtocol: Sendable {
    func prepare(
        schedule: AutomationSchedule,
        triggerContext: AirshipTriggerContext?
    ) async -> SchedulePrepareResult

    func cancelled(schedule: AutomationSchedule) async
}

protocol AutomationPreparerDelegate<PrepareDataIn, PrepareDataOut>: Sendable {
    associatedtype PrepareDataIn: Sendable
    associatedtype PrepareDataOut: Sendable

    func prepare(
        data: PrepareDataIn,
        preparedScheduleInfo: PreparedScheduleInfo
    ) async throws -> PrepareDataOut

    func cancelled(scheduleID: String) async
}

struct AutomationPreparer: AutomationPreparerProtocol {
    private let actionPreparer: any AutomationPreparerDelegate<AirshipJSON, AirshipJSON>
    private let messagePreparer: any AutomationPreparerDelegate<InAppMessage, PreparedInAppMessageData>

    private let deferredResolver: AirshipDeferredResolverProtocol
    private let frequencyLimits: FrequencyLimitManagerProtocol
    private let audienceChecker: DeviceAudienceChecker
    private let experiments: ExperimentDataProvider
    private let remoteDataAccess: AutomationRemoteDataAccessProtocol
    private let prepareQueue: RetryingQueue<SchedulePrepareResult> = RetryingQueue()
    
    private static let deferredResultKey: String = "AirshipAutomation#deferredResult"
    private static let defaultMessageType: String = "transactional"
    private let deviceInfoProviderFactory: @Sendable (String?) -> AudienceDeviceInfoProvider

    @MainActor
    init(
        actionPreparer: any AutomationPreparerDelegate<AirshipJSON, AirshipJSON>,
        messagePreparer: any AutomationPreparerDelegate<InAppMessage, PreparedInAppMessageData>,
        deferredResolver: AirshipDeferredResolverProtocol,
        frequencyLimits: FrequencyLimitManagerProtocol,
        audienceChecker: DeviceAudienceChecker = DefaultDeviceAudienceChecker(),
        experiments: ExperimentDataProvider,
        remoteDataAccess: AutomationRemoteDataAccessProtocol,
        deviceInfoProviderFactory: @escaping @Sendable (String?) -> AudienceDeviceInfoProvider = { contactID in
            CachingAudienceDeviceInfoProvider(contactID: contactID)
        }
    ) {
        self.actionPreparer = actionPreparer
        self.messagePreparer = messagePreparer
        self.deferredResolver = deferredResolver
        self.frequencyLimits = frequencyLimits
        self.audienceChecker = audienceChecker
        self.experiments = experiments
        self.remoteDataAccess = remoteDataAccess
        self.deviceInfoProviderFactory = deviceInfoProviderFactory
    }

    func cancelled(schedule: AutomationSchedule) async {
        if schedule.isInAppMessageType {
            await self.messagePreparer.cancelled(scheduleID: schedule.identifier)
        } else {
            await self.actionPreparer.cancelled(scheduleID: schedule.identifier)
        }
    }

    func prepare(
        schedule: AutomationSchedule,
        triggerContext: AirshipTriggerContext?
    ) async -> SchedulePrepareResult {

        return await prepareQueue.run(name: "schedule: \(schedule.identifier)") { retryState in

            guard await !self.remoteDataAccess.requiresUpdate(schedule: schedule) else {
                await self.remoteDataAccess.waitFullRefresh(schedule: schedule)
                return .success(result: .invalidate)
            }

            guard await self.remoteDataAccess.bestEffortRefresh(schedule: schedule) else {
                return .success(result: .invalidate)
            }

            var frequencyChecker: FrequencyCheckerProtocol!
            do {
                frequencyChecker = try await self.frequencyLimits.getFrequencyChecker(
                    constraintIDs: schedule.frequencyConstraintIDs
                )
            } catch {
                AirshipLogger.error("Failed to fetch frequency checker for schedule \(schedule.identifier) error: \(error)")
                await self.remoteDataAccess.notifyOutdated(schedule: schedule)
                return .success(result: .invalidate)
            }

            guard await !frequencyChecker.isOverLimit else {
                return .success(result: .skip, ignoreReturnOrder: true)
            }

            let deviceInfoProvider = self.deviceInfoProviderFactory(
                self.remoteDataAccess.contactID(forSchedule: schedule)
            )

            if let audience = schedule.audience {
                let match = try await self.audienceChecker.evaluate(
                    audience: audience.audienceSelector,
                    newUserEvaluationDate: schedule.created ?? .distantPast,
                    deviceInfoProvider: deviceInfoProvider
                )

                if (!match) {
                    return .success(
                        result: schedule.missedAudiencePrepareResult,
                        ignoreReturnOrder: true
                    )
                }
            }

            let experimentResult: ExperimentResult? = if schedule.evaluateExperiments {
                try await self.experiments.evaluateExperiments(
                    info: MessageInfo(
                        messageType: schedule.messageType ?? Self.defaultMessageType,
                        campaignsJSON: schedule.campaigns
                    ),
                    deviceInfoProvider: deviceInfoProvider
                )
            } else {
                nil
            }

            let scheduleInfo = PreparedScheduleInfo(
                scheduleID: schedule.identifier,
                campaigns: schedule.campaigns,
                contactID: await deviceInfoProvider.stableContactID,
                experimentResult: experimentResult,
                reportingContext: schedule.reportingContext
            )

            return try await self.prepareData(
                data: schedule.data,
                triggerContext: triggerContext,
                deviceInfoProvider: deviceInfoProvider,
                scheduleInfo: scheduleInfo,
                frequencyChecker: frequencyChecker,
                schedule: schedule,
                retryState: retryState
            )
        }
    }

    private func prepareData(
        data: AutomationSchedule.ScheduleData,
        triggerContext: AirshipTriggerContext?,
        deviceInfoProvider: AudienceDeviceInfoProvider,
        scheduleInfo: PreparedScheduleInfo,
        frequencyChecker: FrequencyCheckerProtocol?,
        schedule: AutomationSchedule,
        retryState: RetryingQueue<SchedulePrepareResult>.State
    ) async throws -> RetryingQueue<SchedulePrepareResult>.Result {
        switch (data) {
        case .actions(let data):
            let result = try await self.actionPreparer.prepare(
                data: data,
                preparedScheduleInfo: scheduleInfo
            )

            let preparedSchedule = PreparedSchedule(
                info: scheduleInfo,
                data: .actions(result),
                frequencyChecker: frequencyChecker
            )

            return .success(result: .prepared(preparedSchedule))

        case .inAppMessage(let data):
            let result = try await self.messagePreparer.prepare(
                data: data,
                preparedScheduleInfo: scheduleInfo
            )

            let preparedSchedule = PreparedSchedule(
                info: scheduleInfo,
                data: .inAppMessage(result),
                frequencyChecker: frequencyChecker
            )
            return .success(result: .prepared(preparedSchedule))

        case .deferred(let deferred):
            return try await self.prepareDeferred(
                deferred: deferred,
                triggerContext: triggerContext,
                deviceInfoProvider: deviceInfoProvider,
                schedule: schedule,
                frequencyChecker: frequencyChecker,
                retryState: retryState
            ) { data in
                try await self.prepareData(
                    data: data,
                    triggerContext: triggerContext,
                    deviceInfoProvider: deviceInfoProvider,
                    scheduleInfo: scheduleInfo,
                    frequencyChecker: frequencyChecker,
                    schedule: schedule,
                    retryState: retryState
                )
            }
        }
    }

    private func prepareDeferred(
        deferred: DeferredAutomationData,
        triggerContext: AirshipTriggerContext?,
        deviceInfoProvider: AudienceDeviceInfoProvider,
        schedule: AutomationSchedule,
        frequencyChecker: FrequencyCheckerProtocol?,
        retryState: RetryingQueue<SchedulePrepareResult>.State,
        onResult: @escaping @Sendable (AutomationSchedule.ScheduleData) async throws -> RetryingQueue<SchedulePrepareResult>.Result
    ) async throws -> RetryingQueue<SchedulePrepareResult>.Result {

        guard let channelID = deviceInfoProvider.channelID else {
            AirshipLogger.info("Unable to resolve deferred until channel is created")
            return .retry
        }

        let request = DeferredRequest(
            url: deferred.url,
            channelID: channelID,
            triggerContext: triggerContext,
            locale: deviceInfoProvider.locale,
            notificationOptIn: await deviceInfoProvider.isUserOptedInPushNotifications
        )

        if let cached: AutomationSchedule.ScheduleData = await retryState.value(key: Self.deferredResultKey) {
            return try await onResult(cached)
        }

        let result: AirshipDeferredResult<DeferredScheduleResult> = await deferredResolver.resolve(request: request) { data in
            return try AirshipJSON.defaultDecoder.decode(DeferredScheduleResult.self, from: data)
        }

        switch (result) {
        case .success(let result):
            if (result.isAudienceMatch) {
                switch (deferred.type) {
                case .actions:
                    guard let actions = result.actions else {
                        AirshipLogger.error("Failed to get result for deferred.")
                        return .retry
                    }
                    return try await onResult(.actions(actions))
                case .inAppMessage:
                    guard var message = result.message else {
                        AirshipLogger.error("Failed to get result for deferred.")
                        return .retry
                    }
                    message.source = .remoteData
                    return try await onResult(.inAppMessage(message))
                }
            } else {
                return .success(
                    result: schedule.missedAudiencePrepareResult,
                    ignoreReturnOrder: true
                )
            }
        case .timedOut:
            if (deferred.retryOnTimeOut != false) {
                return .retry
            }
            return .success(result: .penalize, ignoreReturnOrder: true)
        case .outOfDate:
            await self.remoteDataAccess.notifyOutdated(schedule: schedule)
            return .success(result: .invalidate)
        case .notFound:
            await self.remoteDataAccess.notifyOutdated(schedule: schedule)
            return .success(result: .invalidate)
        case .retriableError(retryAfter: let retryAfter):
            if let retryAfter {
                return .retryAfter(retryAfter)
            } else {
                return .retry
            }
#if canImport(AirshipCore)
        @unknown default:
            // Not possible
            return .retry
#endif
        }
    }
}

fileprivate extension AutomationSchedule {
    var missedAudiencePrepareResult: SchedulePrepareResult {
        switch (self.audience?.missBehavior ?? .cancel) {
        case .cancel: return .cancel
        case .penalize: return .penalize
        case .skip: return .skip
        }
    }

    var evaluateExperiments: Bool {
        return self.isInAppMessageType && self.bypassHoldoutGroups != true
    }
}

