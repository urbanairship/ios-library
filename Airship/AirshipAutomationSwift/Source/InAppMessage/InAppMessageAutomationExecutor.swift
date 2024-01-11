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
    private let conditionsChangedNotifier: Notifier

    init(
        sceneManager: InAppMessageSceneManagerProtocol,
        assetManager: AssetCacheManagerProtocol,
        analyticsFactory: InAppMessageAnalyticsFactoryProtocol = InAppMessageAnalyticsFactory(),
        conditionsChangedNotifier: Notifier
    ) {
        self.sceneManager = sceneManager
        self.assetManager = assetManager
        self.analyticsFactory = analyticsFactory
        self.conditionsChangedNotifier = conditionsChangedNotifier
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
            Task { [conditionsChangedNotifier] in
                await data.displayAdapter.waitForReady()
                await conditionsChangedNotifier.notify()
            }
            return .notReady
        }

        guard data.displayCoordinator.isReady else {
            AirshipLogger.info("Schedule \(preparedScheduleInfo.scheduleID) display coordinator not ready")
            Task { [conditionsChangedNotifier] in
                await data.displayCoordinator.waitForReady()
                await conditionsChangedNotifier.notify()
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
    func execute(data: PreparedInAppMessageData, preparedScheduleInfo: PreparedScheduleInfo) async throws {
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

        await data.displayAdapter.display(scene: scene, analytics: analytics)

        // Finished
        data.displayCoordinator.messageFinishedDisplaying(data.message)
        self.delegates.displayDelegate?.messageFinishedDisplaying(
            data.message,
            scheduleID: preparedScheduleInfo.scheduleID
       )

        // Clean up assets
        await self.assetManager.clearCache(identifier: preparedScheduleInfo.scheduleID)
    }

    func interrupted(preparedScheduleInfo: PreparedScheduleInfo) async {
        // TODO analytics
        // Clean up assets
        await self.assetManager.clearCache(identifier: preparedScheduleInfo.scheduleID)
    }


    /// Delegates holder so I can keep the executor sendable
    private final class Delegates: @unchecked Sendable {
        @MainActor
        weak var displayDelegate: InAppMessageDisplayDelegate?

    }
}


