/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

final class InAppMessageAutomationExecutor: AutomationExecutorDelegate {
    typealias ExecutionData = PreparedInAppMessageData

    private let delegates: Delegates = Delegates()
    private let sceneManager: InAppMessageSceneManagerProtocol
    private let assetManager: AssetCacheManagerProtocol
    private let analyticsFactory: InAppMessageAnalyticsFactoryProtocol
    private let scheduleConditionsChangedNotifier: ScheduleConditionsChangedNotifier
    private let actionRunner: AutomationActionRunnerProtocol

    init(
        sceneManager: InAppMessageSceneManagerProtocol,
        assetManager: AssetCacheManagerProtocol,
        analyticsFactory: InAppMessageAnalyticsFactoryProtocol,
        scheduleConditionsChangedNotifier: ScheduleConditionsChangedNotifier,
        actionRunner: AutomationActionRunnerProtocol = AutomationActionRunner()
    ) {
        self.sceneManager = sceneManager
        self.assetManager = assetManager
        self.analyticsFactory = analyticsFactory
        self.scheduleConditionsChangedNotifier = scheduleConditionsChangedNotifier
        self.actionRunner = actionRunner
    }

    @MainActor
    weak var displayDelegate: InAppMessageDisplayDelegate? {
        get {
            return delegates.displayDelegate
        }
        set {
            delegates.displayDelegate = newValue
        }
    }

    @MainActor
    weak var sceneDelegate: InAppMessageSceneDelegate? {
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

        let isReady = self.delegates.displayDelegate?.isMessageReadyToDisplay(
            data.message,
            scheduleID: preparedScheduleInfo.scheduleID
        )

        guard isReady != false else {
            AirshipLogger.info("Schedule \(preparedScheduleInfo.scheduleID) InAppMessageDisplayDelegate not ready")
            return .notReady
        }

        return .ready
    }

    @MainActor
    func execute(data: PreparedInAppMessageData, preparedScheduleInfo: PreparedScheduleInfo) async throws -> ScheduleExecuteResult {
        let scene = try self.sceneManager.scene(forMessage: data.message)

        // Display
        self.delegates.displayDelegate?.messageWillDisplay(
             data.message,
             scheduleID: preparedScheduleInfo.scheduleID
        )
        data.displayCoordinator.messageWillDisplay(data.message)
        let analytics = analyticsFactory.makeAnalytics(
            message: data.message,
            preparedScheduleInfo: preparedScheduleInfo
        )

        var result: ScheduleExecuteResult = .finished
        
        let experimentResult = preparedScheduleInfo.experimentResult
        if let experimentResult = experimentResult, experimentResult.isMatch {
            analytics.recordEvent(
                InAppResolutionEvent.control(experimentResult: experimentResult),
                layoutContext: nil
            )
        } else {
            do {
                let displayResult = try await data.displayAdapter.display(scene: scene, analytics: analytics)
                switch (displayResult) {
                case .cancel:
                    result = .cancel
                case .finished:
                    result = .finished
                }

                if let actions = data.message.actions  {
                    actionRunner.runActionsAsync(actions, situation: .manualInvocation, metadata: [:])
                }
            } catch {
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

        let analytics = self.analyticsFactory.makeAnalytics(message: message, preparedScheduleInfo: preparedScheduleInfo)
        analytics.recordEvent(
            InAppResolutionEvent.interrupted(),
            layoutContext: nil
        )

        await self.assetManager.clearCache(identifier: preparedScheduleInfo.scheduleID)
        return .finish
    }

    /// Delegates holder so I can keep the executor sendable
    private final class Delegates: @unchecked Sendable {
        @MainActor
        weak var displayDelegate: InAppMessageDisplayDelegate?

    }
}


