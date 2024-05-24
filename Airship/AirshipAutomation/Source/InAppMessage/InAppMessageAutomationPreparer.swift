/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Any data needed by in-app message to handle displaying the message
struct PreparedInAppMessageData: Sendable {
    var message: InAppMessage
    var displayAdapter: DisplayAdapter
    var displayCoordinator: DisplayCoordinator
    var analytics: InAppMessageAnalyticsProtocol
    var actionRunner: InAppActionRunner & ThomasActionRunner
}

final class InAppMessageAutomationPreparer: AutomationPreparerDelegate {
    typealias PrepareDataIn = InAppMessage
    typealias PrepareDataOut = PreparedInAppMessageData

    private let displayCoordinatorManager: DisplayCoordinatorManagerProtocol
    private let displayAdapterFactory: DisplayAdapterFactoryProtocol
    private let assetManager: AssetCacheManagerProtocol
    private let analyticsFactory: InAppMessageAnalyticsFactoryProtocol
    private let actionRunnerFactory: InAppActionRunnerFactoryProtocol

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
        assetManager: AssetCacheManagerProtocol,
        displayCoordinatorManager: DisplayCoordinatorManagerProtocol,
        displayAdapterFactory: DisplayAdapterFactoryProtocol = DisplayAdapterFactory(),
        analyticsFactory: InAppMessageAnalyticsFactoryProtocol,
        actionRunnerFactory: InAppActionRunnerFactoryProtocol = InAppActionRunnerFactory()
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
            args: DisplayAdapterArgs(message: data, assets: assets, _actionRunner: actionRunner)
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

    private func prepareAssets(message: InAppMessage, scheduleID: String, skip: Bool) async throws -> AirshipCachedAssetsProtocol {
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
        factoryBlock: @escaping @Sendable (DisplayAdapterArgs) -> CustomDisplayAdapter?
    ) {
        self.displayAdapterFactory.setAdapterFactoryBlock(
            forType: type,
            factoryBlock: { args in
                factoryBlock(args)
            }
        )
    }
}
