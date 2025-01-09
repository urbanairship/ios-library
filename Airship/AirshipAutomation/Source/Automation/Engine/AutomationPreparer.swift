/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

protocol AutomationPreparerProtocol: Sendable {
    func prepare(
        schedule: AutomationSchedule,
        triggerContext: AirshipTriggerContext?,
        triggerSessionID: String
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

    private let deferredResolver: any AirshipDeferredResolverProtocol
    private let frequencyLimits: any FrequencyLimitManagerProtocol
    private let audienceChecker: any DeviceAudienceChecker
    private let experiments: any ExperimentDataProvider
    private let remoteDataAccess: any AutomationRemoteDataAccessProtocol
    private let queues: Queues
    private let config: RuntimeConfig
    private let additionalAudienceResolver: any AdditionalAudienceCheckerResolverProtocol

    private static let deferredResultKey: String = "AirshipAutomation#deferredResult"
    private static let defaultMessageType: String = "transactional"
    private let deviceInfoProviderFactory: @Sendable (String?) -> any AudienceDeviceInfoProvider

    @MainActor
    init(
        actionPreparer: any AutomationPreparerDelegate<AirshipJSON, AirshipJSON>,
        messagePreparer: any AutomationPreparerDelegate<InAppMessage, PreparedInAppMessageData>,
        deferredResolver: any AirshipDeferredResolverProtocol,
        frequencyLimits: any FrequencyLimitManagerProtocol,
        audienceChecker: any DeviceAudienceChecker,
        experiments: any ExperimentDataProvider,
        remoteDataAccess: any AutomationRemoteDataAccessProtocol,
        config: RuntimeConfig,
        deviceInfoProviderFactory: @escaping @Sendable (String?) -> any AudienceDeviceInfoProvider = { contactID in
            CachingAudienceDeviceInfoProvider(contactID: contactID)
        },
        additionalAudienceResolver: any AdditionalAudienceCheckerResolverProtocol
    ) {
        self.actionPreparer = actionPreparer
        self.messagePreparer = messagePreparer
        self.deferredResolver = deferredResolver
        self.frequencyLimits = frequencyLimits
        self.audienceChecker = audienceChecker
        self.experiments = experiments
        self.remoteDataAccess = remoteDataAccess
        self.deviceInfoProviderFactory = deviceInfoProviderFactory
        self.config = config
        self.queues = Queues(config: config)
        self.additionalAudienceResolver = additionalAudienceResolver
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
        triggerContext: AirshipTriggerContext?,
        triggerSessionID: String
    ) async -> SchedulePrepareResult {
        AirshipLogger.trace("Preparing \(schedule.identifier)")

        let queue = await self.queues.queue(name: schedule.queue)
        
        return await queue.run(name: "schedule: \(schedule.identifier)") { retryState in

            guard await !self.remoteDataAccess.requiresUpdate(schedule: schedule) else {
                AirshipLogger.trace("Schedule out of date \(schedule.identifier)")
                await self.remoteDataAccess.waitFullRefresh(schedule: schedule)
                return .success(result: .invalidate)
            }

            guard await self.remoteDataAccess.bestEffortRefresh(schedule: schedule) else {
                AirshipLogger.trace("Schedule out of date \(schedule.identifier)")
                return .success(result: .invalidate)
            }

            var frequencyChecker: (any FrequencyCheckerProtocol)!
            do {
                frequencyChecker = try await self.frequencyLimits.getFrequencyChecker(
                    constraintIDs: schedule.frequencyConstraintIDs
                )
            } catch {
                AirshipLogger.error("Failed to fetch frequency checker for schedule \(schedule.identifier) error: \(error)")
                return .success(result: .skip)
            }

            let deviceInfoProvider = self.deviceInfoProviderFactory(
                self.remoteDataAccess.contactID(forSchedule: schedule)
            )

            let audience = CompoundDeviceAudienceSelector.combine(
                compoundSelector: schedule.compoundAudience?.selector,
                deviceSelector: schedule.audience?.audienceSelector
            )

            if let audience {
                let match = try await self.audienceChecker.evaluate(
                    audienceSelector: audience,
                    newUserEvaluationDate: schedule.created ?? .distantPast,
                    deviceInfoProvider: deviceInfoProvider
                )

                if (!match.isMatch) {
                    AirshipLogger.trace("Local audience miss \(schedule.identifier)")
                    return .success(
                        result: schedule.audienceMissBehaviorResult,
                        ignoreReturnOrder: true
                    )
                }
            }


            let experimentResult: ExperimentResult? = if schedule.evaluateExperiments {
                try await self.experiments.evaluateExperiments(
                    info: MessageInfo(
                        messageType: schedule.messageType ?? Self.defaultMessageType,
                        campaigns: schedule.campaigns
                    ),
                    deviceInfoProvider: deviceInfoProvider
                )
            } else {
                nil
            }

            AirshipLogger.trace("Preparing data \(schedule.identifier)")

            return try await self.prepareData(
                data: schedule.data,
                schedule: schedule,
                retryState: retryState,
                deferredRequest: { url in
                    DeferredRequest(
                        url: url,
                        channelID: try await deviceInfoProvider.channelID,
                        triggerContext: triggerContext,
                        locale: deviceInfoProvider.locale,
                        notificationOptIn: await deviceInfoProvider.isUserOptedInPushNotifications
                    )
                },
                prepareScheduleInfo: {
                    let result = try await additionalAudienceResolver.resolve(
                        deviceInfoProvider: deviceInfoProvider,
                        additionalAudienceCheckOverrides: schedule.additionalAudienceCheckOverrides
                    )

                    return PreparedScheduleInfo(
                        scheduleID: schedule.identifier,
                        productID: schedule.productID,
                        campaigns: schedule.campaigns,
                        contactID: await deviceInfoProvider.stableContactInfo.contactID,
                        experimentResult: experimentResult,
                        reportingContext: schedule.reportingContext,
                        triggerSessionID: triggerSessionID,
                        additionalAudienceCheckResult: result,
                        priority: schedule.priority ?? 0
                    )
                },
                prepareSchedule: { [frequencyChecker] scheduleInfo, data in
                    return PreparedSchedule(
                        info: scheduleInfo,
                        data: data,
                        frequencyChecker: frequencyChecker
                    )
                }
            )
        }
    }

    private func prepareData(
        data: AutomationSchedule.ScheduleData,
        schedule: AutomationSchedule,
        retryState: RetryingQueue<SchedulePrepareResult>.State,
        deferredRequest:  @escaping @Sendable (URL) async throws -> DeferredRequest,
        prepareScheduleInfo:  @escaping @Sendable () async throws -> PreparedScheduleInfo,
        prepareSchedule:  @escaping @Sendable (PreparedScheduleInfo, PreparedScheduleData) -> PreparedSchedule
    ) async throws -> RetryingQueue<SchedulePrepareResult>.Result {
        switch (data) {
        case .actions(let data):
            let preparedInfo = try await prepareScheduleInfo()
            let result = try await self.actionPreparer.prepare(
                data: data,
                preparedScheduleInfo: preparedInfo
            )

            let preparedSchedule = prepareSchedule(preparedInfo, .actions(result))
            return .success(result: .prepared(preparedSchedule))

        case .inAppMessage(let data):
            guard data.displayContent.validate() else {
                AirshipLogger.debug("⚠️ Message did not pass validation: \(data.name) - skipping.")
                return .success(result: .skip)
            }

            let preparedInfo = try await prepareScheduleInfo()
            let result = try await self.messagePreparer.prepare(
                data: data,
                preparedScheduleInfo: preparedInfo
            )

            let preparedSchedule = prepareSchedule(preparedInfo, .inAppMessage(result))
            return .success(result: .prepared(preparedSchedule))

        case .deferred(let deferred):
            return try await self.prepareDeferred(
                deferred: deferred,
                schedule: schedule,
                retryState: retryState,
                deferredRequest: deferredRequest
            ) { data in
                try await self.prepareData(
                    data: data,
                    schedule: schedule,
                    retryState: retryState,
                    deferredRequest: deferredRequest,
                    prepareScheduleInfo: prepareScheduleInfo,
                    prepareSchedule: prepareSchedule
                )
            }
        }
    }


    private func prepareDeferred(
        deferred: DeferredAutomationData,
        schedule: AutomationSchedule,
        retryState: RetryingQueue<SchedulePrepareResult>.State,
        deferredRequest:  @escaping @Sendable (URL) async throws -> DeferredRequest,
        onResult: @escaping @Sendable (AutomationSchedule.ScheduleData) async throws -> RetryingQueue<SchedulePrepareResult>.Result
    ) async throws -> RetryingQueue<SchedulePrepareResult>.Result {

        AirshipLogger.trace("Resolving deferred \(schedule.identifier)")

        let request = try await deferredRequest(deferred.url)

        if let cached: AutomationSchedule.ScheduleData = await retryState.value(key: Self.deferredResultKey) {
            AirshipLogger.trace("Deferred resolved from cache \(schedule.identifier)")

            return try await onResult(cached)
        }

        let result: AirshipDeferredResult<DeferredScheduleResult> = await deferredResolver.resolve(request: request) { data in
            return try JSONDecoder().decode(DeferredScheduleResult.self, from: data)
        }

        AirshipLogger.trace("Deferred result \(schedule.identifier) \(result)")

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
                    result: schedule.audienceMissBehaviorResult,
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
        case .retriableError(retryAfter: let retryAfter, statusCode: _):
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
    var audienceMissBehaviorResult: SchedulePrepareResult {
        if let compoundAudience {
            return compoundAudience.missBehavior.schedulePrepareResult
        } else if let audienceMiss = audience?.missBehavior {
            return audienceMiss.schedulePrepareResult
        } else {
            return .penalize
        }
    }

    var evaluateExperiments: Bool {
        return self.isInAppMessageType && self.bypassHoldoutGroups != true
    }
}

fileprivate actor Queues {
    var queues: [String: RetryingQueue<SchedulePrepareResult>] = [:]
    lazy var defaultQueue: RetryingQueue<SchedulePrepareResult>  = {
        return RetryingQueue(config: config.remoteConfig.iaaConfig?.retryingQueue)
    }()
    private let config: RuntimeConfig

    @MainActor
    init(config: RuntimeConfig) {
        self.config = config
    }
    
    func queue(name: String?) -> RetryingQueue<SchedulePrepareResult> {
        guard let name = name, !name.isEmpty else {
            return defaultQueue
        }

        if let queue = queues[name] {
            return queue
        }

        let queue: RetryingQueue<SchedulePrepareResult> = RetryingQueue(config: config.remoteConfig.iaaConfig?.retryingQueue)       
        queues[name] = queue
        return queue
    }
}

