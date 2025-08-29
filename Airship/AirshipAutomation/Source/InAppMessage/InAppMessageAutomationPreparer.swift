/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Any data needed by in-app message to handle displaying the message
struct PreparedInAppMessageData: Sendable {
    var message: InAppMessage
    var displayAdapter: any DisplayAdapter
    var displayCoordinator: any DisplayCoordinator
    var analytics: any InAppMessageAnalyticsProtocol
    var actionRunner: any InAppActionRunner & ThomasActionRunner
}

final class InAppMessageAutomationPreparer: AutomationPreparerDelegate {
    typealias PrepareDataIn = InAppMessage
    typealias PrepareDataOut = PreparedInAppMessageData

    private let displayCoordinatorManager: any DisplayCoordinatorManagerProtocol
    private let displayAdapterFactory: any DisplayAdapterFactoryProtocol
    private let assetManager: any AssetCacheManagerProtocol
    private let analyticsFactory: any InAppMessageAnalyticsFactoryProtocol
    private let actionRunnerFactory: any InAppActionRunnerFactoryProtocol

    @MainActor
    public var displayInterval: TimeInterval {
        get {
            return displayCoordinatorManager.displayInterval
        }
        set {
            displayCoordinatorManager.displayInterval = newValue
        }
    }

    init(
        assetManager: any AssetCacheManagerProtocol,
        displayCoordinatorManager: any DisplayCoordinatorManagerProtocol,
        displayAdapterFactory: any DisplayAdapterFactoryProtocol = DisplayAdapterFactory(),
        analyticsFactory: any InAppMessageAnalyticsFactoryProtocol,
        actionRunnerFactory: any InAppActionRunnerFactoryProtocol = InAppActionRunnerFactory()
    ) {
        self.assetManager = assetManager
        self.displayCoordinatorManager = displayCoordinatorManager
        self.displayAdapterFactory = displayAdapterFactory
        self.analyticsFactory = analyticsFactory
        self.actionRunnerFactory = actionRunnerFactory
    }

    func prepare(
        data: InAppMessage,
        preparedScheduleInfo: PreparedScheduleInfo
    ) async throws -> PreparedInAppMessageData {
        let assets = try await self.prepareAssets(
            message: data,
            scheduleID: preparedScheduleInfo.scheduleID,
            skip: preparedScheduleInfo.additionalAudienceCheckResult == false || preparedScheduleInfo.experimentResult?.isMatch == true
        )

        let displayCoordinator = self.displayCoordinatorManager.displayCoordinator(message: data)

        let analytics = await self.analyticsFactory.makeAnalytics(
            preparedScheduleInfo: preparedScheduleInfo,
            message: data
        )

        let actionRunner = self.actionRunnerFactory.makeRunner(message: data, analytics: analytics)

        let displayAdapter = try await self.displayAdapterFactory.makeAdapter(
            args: DisplayAdapterArgs(
                message: data,
                assets: assets,
                priority: preparedScheduleInfo.priority,
                _actionRunner: actionRunner
            )
        )

        return PreparedInAppMessageData(
            message: data,
            displayAdapter: displayAdapter,
            displayCoordinator: displayCoordinator,
            analytics: analytics,
            actionRunner: actionRunner
        )
    }

    func cancelled(scheduleID: String) async {
        AirshipLogger.trace("Execution cancelled \(scheduleID)")
        await self.assetManager.clearCache(identifier: scheduleID)
    }

    private func prepareAssets(message: InAppMessage, scheduleID: String, skip: Bool) async throws -> any AirshipCachedAssetsProtocol {
        // - prepare assets
        let imageURLs: [String] = if skip {
            []
        } else {
            message.urlInfos
                .compactMap { info in
                    guard case .image(let url, let prefetch) = info, prefetch else {
                        return nil
                    }
                    return url
                }
        }

        AirshipLogger.trace("Preparing assets \(scheduleID): \(imageURLs)")

        return try await self.assetManager.cacheAssets(
            identifier: scheduleID,
            assets: imageURLs
        )
    }

    @MainActor
    func setAdapterFactoryBlock(
        forType type: CustomDisplayAdapterType,
        factoryBlock: @escaping @Sendable (DisplayAdapterArgs) -> (any CustomDisplayAdapter)?
    ) {
        self.displayAdapterFactory.setAdapterFactoryBlock(
            forType: type,
            factoryBlock: { args in
                factoryBlock(args)
            }
        )
    }
}
