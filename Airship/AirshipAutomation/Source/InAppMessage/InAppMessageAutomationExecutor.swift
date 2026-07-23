/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipInternal) import AirshipBasement

@_spi(AirshipInternal) import AirshipCore
@_spi(AirshipInternal) import AirshipScenes

final class InAppMessageAutomationExecutor: AutomationExecutorDelegate {
    typealias ExecutionData = PreparedInAppMessageData

    private let delegates: Delegates = Delegates()
    private let assetManager: any AssetCacheManagerProtocol
    private let analyticsFactory: any InAppMessageAnalyticsFactoryProtocol
    private let scheduleConditionsChangedNotifier: ScheduleConditionsChangedNotifier

    /// Injected at module load so the view-testing `displayTest` path can build a layout
    /// adapter without resolving the AI manager from the shared `Airship` instance.
    /// `nil` when no on-device model is available.
    private let aiManager: (any AirshipAI.InternalManager)?

#if os(macOS)
    init(
        assetManager: any AssetCacheManagerProtocol,
        analyticsFactory: any InAppMessageAnalyticsFactoryProtocol,
        scheduleConditionsChangedNotifier: ScheduleConditionsChangedNotifier,
        aiManager: (any AirshipAI.InternalManager)? = nil
    ) {
        self.assetManager = assetManager
        self.analyticsFactory = analyticsFactory
        self.scheduleConditionsChangedNotifier = scheduleConditionsChangedNotifier
        self.aiManager = aiManager
    }
#else
    private let sceneManager: any InAppMessageSceneManagerProtocol


    @MainActor
    weak var sceneDelegate: (any InAppMessageSceneDelegate)? {
        get {
            return sceneManager.delegate
        }
        set {
            sceneManager.delegate = newValue
        }
    }

    init(
        sceneManager: any InAppMessageSceneManagerProtocol,
        assetManager: any AssetCacheManagerProtocol,
        analyticsFactory: any InAppMessageAnalyticsFactoryProtocol,
        scheduleConditionsChangedNotifier: ScheduleConditionsChangedNotifier,
        aiManager: (any AirshipAI.InternalManager)? = nil
    ) {
        self.sceneManager = sceneManager
        self.assetManager = assetManager
        self.analyticsFactory = analyticsFactory
        self.scheduleConditionsChangedNotifier = scheduleConditionsChangedNotifier
        self.aiManager = aiManager
    }
#endif

    @MainActor
    weak var displayDelegate: (any InAppMessageDisplayDelegate)? {
        get {
            return delegates.displayDelegate
        }
        set {
            delegates.displayDelegate = newValue
        }
    }

    @MainActor
    var onIsReadyToDisplay: (@MainActor @Sendable (InAppMessage, String) -> Bool)? {
        get {
            return delegates.onIsReadyToDisplay
        }
        set {
            delegates.onIsReadyToDisplay = newValue
        }
    }
    



    func isReady(
        data: PreparedInAppMessageData,
        preparedScheduleInfo: PreparedScheduleInfo
    ) -> ScheduleReadyResult {

        guard data.displayAdapter.isReady else {
            AirshipLogger.info("Schedule \(preparedScheduleInfo.scheduleID) display adapter not ready")
            Task { [scheduleConditionsChangedNotifier] in
                await data.displayAdapter.waitForReady()
                scheduleConditionsChangedNotifier.notify()
            }
            return .notReady
        }

        guard data.displayCoordinator.isReady else {
            AirshipLogger.info("Schedule \(preparedScheduleInfo.scheduleID) display coordinator not ready")
            Task { [scheduleConditionsChangedNotifier] in
                await data.displayCoordinator.waitForReady()
                scheduleConditionsChangedNotifier.notify()
            }
            return .notReady
        }

        var isReady: Bool?
        if let onDisplay = self.onIsReadyToDisplay {
            isReady = onDisplay(
                data.message,
                preparedScheduleInfo.scheduleID
            )
        } else if let displayDelegate = self.displayDelegate {
            isReady = displayDelegate.isMessageReadyToDisplay(
                data.message,
                scheduleID: preparedScheduleInfo.scheduleID
            )
        }
        
        guard isReady != false else {
            AirshipLogger.info("Schedule \(preparedScheduleInfo.scheduleID) InAppMessageDisplayDelegate not ready")
            return .notReady
        }

        return .ready
    }

    /// Displays a message directly for view-testing, bypassing the automation pipeline.
    /// Reuses the same scene plumbing as the normal execute path and the AI manager
    /// injected at module load, so nothing is resolved from the shared `Airship` instance.
    @MainActor
    func displayTest(message: InAppMessage) async throws {
        let adapter = try AirshipLayoutDisplayAdapter(
            message: message,
            priority: 0,
            assets: EmptyAirshipCachedAssets(),
            aiManager: self.aiManager
        )

#if os(macOS)
        let displayTarget = AirshipDisplayTarget()
#else
        let displayTarget = AirshipDisplayTarget {
            try self.sceneManager.scene(forMessage: message).scene
        }
#endif

        _ = try await adapter.display(
            displayTarget: displayTarget,
            analytics: LoggingInAppMessageAnalytics()
        )
    }

    @MainActor
    func execute(
        data: PreparedInAppMessageData,
        preparedScheduleInfo: PreparedScheduleInfo
    ) async throws -> ScheduleExecuteResult {
        guard preparedScheduleInfo.additionalAudienceCheckResult else {
            AirshipLogger.info("Schedule \(preparedScheduleInfo.scheduleID) missed additional audience check")
            data.analytics.recordEvent(
                ThomasLayoutResolutionEvent.audienceExcluded(),
                layoutContext: nil
            )
            return .finished
        }

#if os(macOS)
        let displayTarget = AirshipDisplayTarget()
#else
        let displayTarget = AirshipDisplayTarget {
            try self.sceneManager.scene(forMessage: data.message).scene
        }
#endif


        // Display
        self.delegates.displayDelegate?.messageWillDisplay(
             data.message,
             scheduleID: preparedScheduleInfo.scheduleID
        )
        data.displayCoordinator.messageWillDisplay(data.message)

        var result: ScheduleExecuteResult = .finished
        
        let experimentResult = preparedScheduleInfo.experimentResult
        if let experimentResult = experimentResult, experimentResult.isMatch {
            AirshipLogger.info("Schedule \(preparedScheduleInfo.scheduleID) part of experiment")
            data.analytics.recordEvent(
                ThomasLayoutResolutionEvent.control(experimentResult: experimentResult),
                layoutContext: nil
            )
        } else {
            do {
                AirshipLogger.info("Displaying message \(preparedScheduleInfo.scheduleID)")

                let displayResult = try await data.displayAdapter.display(displayTarget: displayTarget, analytics: data.analytics)
                switch (displayResult) {
                case .cancel:
                    result = .cancel
                case .finished:
                    result = .finished
                }

                if let actions = data.message.actions  {
                    data.actionRunner.runAsync(actions: actions)
                }
            } catch {
                data.displayCoordinator.messageFinishedDisplaying(data.message)
                AirshipLogger.error("Failed to display message \(error)")
                // Non-remote-data schedules come from push payloads that won't change — cancel.
                result = data.message.source != .remoteData ? .cancel : .retry
            }
        }

        // Finished
        data.displayCoordinator.messageFinishedDisplaying(data.message)
        self.delegates.displayDelegate?.messageFinishedDisplaying(
            data.message,
            scheduleID: preparedScheduleInfo.scheduleID
       )

        // Clean up assets
        if (result != .retry) {
            await self.assetManager.clearCache(identifier: preparedScheduleInfo.scheduleID)
        }

        return result
    }

    func interrupted(schedule: AutomationSchedule, preparedScheduleInfo: PreparedScheduleInfo) async -> InterruptedBehavior {
        guard case .inAppMessage(let message) = schedule.data else {
            return .finish
        }

        guard !message.isEmbedded else {
            return .retry
        }

        let analytics = await self.analyticsFactory.makeAnalytics(
            preparedScheduleInfo: preparedScheduleInfo,
            message: message
        )

        analytics.recordEvent(
            ThomasLayoutResolutionEvent.interrupted(),
            layoutContext: nil
        )

        await self.assetManager.clearCache(identifier: preparedScheduleInfo.scheduleID)
        return .finish
    }

    @MainActor
    func notifyDisplayConditionsChanged() {
        self.scheduleConditionsChangedNotifier.notify()
    }

    /// Delegates holder so I can keep the executor sendable
    private final class Delegates: Sendable {
        @MainActor
        fileprivate weak var displayDelegate: (any InAppMessageDisplayDelegate)?
        
        @MainActor
        fileprivate var onIsReadyToDisplay: (@MainActor @Sendable (InAppMessage, String) -> Bool)?
    }
}


