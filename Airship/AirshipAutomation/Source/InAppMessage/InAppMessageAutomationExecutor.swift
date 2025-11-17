/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

final class InAppMessageAutomationExecutor: AutomationExecutorDelegate {
    typealias ExecutionData = PreparedInAppMessageData

    private let delegates: Delegates = Delegates()
    private let sceneManager: any InAppMessageSceneManagerProtocol
    private let assetManager: any AssetCacheManagerProtocol
    private let analyticsFactory: any InAppMessageAnalyticsFactoryProtocol
    private let scheduleConditionsChangedNotifier: ScheduleConditionsChangedNotifier

    init(
        sceneManager: any InAppMessageSceneManagerProtocol,
        assetManager: any AssetCacheManagerProtocol,
        analyticsFactory: any InAppMessageAnalyticsFactoryProtocol,
        scheduleConditionsChangedNotifier: ScheduleConditionsChangedNotifier
    ) {
        self.sceneManager = sceneManager
        self.assetManager = assetManager
        self.analyticsFactory = analyticsFactory
        self.scheduleConditionsChangedNotifier = scheduleConditionsChangedNotifier
    }

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
    
    
    @MainActor
    weak var sceneDelegate: (any InAppMessageSceneDelegate)? {
        get {
            return sceneManager.delegate
        }
        set {
            sceneManager.delegate = newValue
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

    @MainActor
    func execute(
        data: PreparedInAppMessageData,
        preparedScheduleInfo: PreparedScheduleInfo
    ) async throws -> ScheduleExecuteResult {
        guard preparedScheduleInfo.additionalAudienceCheckResult else {
            AirshipLogger.info("Schedule \(preparedScheduleInfo.scheduleID) missed additional audience check")
            data.analytics.recordEvent(
                InAppResolutionEvent.audienceExcluded(),
                layoutContext: nil
            )
            return .finished
        }

        let displayTarget = AirshipDisplayTarget {
            try self.sceneManager.scene(forMessage: data.message).scene
        }

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
                InAppResolutionEvent.control(experimentResult: experimentResult),
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
                result = .retry
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
            InAppResolutionEvent.interrupted(),
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
        weak var displayDelegate: (any InAppMessageDisplayDelegate)?
        
        @MainActor
        var onIsReadyToDisplay: (@MainActor @Sendable (InAppMessage, String) -> Bool)?
    }
}


