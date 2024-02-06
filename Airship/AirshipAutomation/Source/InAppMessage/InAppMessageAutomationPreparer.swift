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
}

final class InAppMessageAutomationPreparer: AutomationPreparerDelegate {
    typealias PrepareDataIn = InAppMessage
    typealias PrepareDataOut = PreparedInAppMessageData

    private let displayCoordinatorManager: DisplayCoordinatorManagerProtocol
    private let displayAdapterFactory: DisplayAdapterFactoryProtocol
    private let assetManager: AssetCacheManagerProtocol

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
        displayAdapterFactory: DisplayAdapterFactoryProtocol = DisplayAdapterFactory()
    ) {
        self.assetManager = assetManager
        self.displayCoordinatorManager = displayCoordinatorManager
        self.displayAdapterFactory = displayAdapterFactory
    }

    func prepare(
        data: InAppMessage,
        preparedScheduleInfo: PreparedScheduleInfo
    ) async throws -> PreparedInAppMessageData {
        let assets = try await self.prepareAssets(
            message: data,
            scheduleID: preparedScheduleInfo.scheduleID
        )

        AirshipLogger.trace("Making display coordinator \(preparedScheduleInfo.scheduleID)")
        let displayCoordinator = self.displayCoordinatorManager.displayCoordinator(message: data)
        let displayAdapter = try await self.displayAdapterFactory.makeAdapter(
            message: data,
            assets: assets
        )

        return PreparedInAppMessageData(
            message: data,
            displayAdapter: displayAdapter,
            displayCoordinator: displayCoordinator
        )
    }

    func cancelled(scheduleID: String) async {
        AirshipLogger.trace("Execution cancelled \(scheduleID)")
        await self.assetManager.clearCache(identifier: scheduleID)
    }

    private func prepareAssets(message: InAppMessage, scheduleID: String) async throws -> AirshipCachedAssetsProtocol {
        // - prepare assets
        let imageURLs: [String] = message.urlInfos
            .compactMap { info in
                guard case .image(let url, let prefetch) = info, prefetch else {
                    return nil
                }
                return url
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
        factoryBlock: @escaping @Sendable (InAppMessage, AirshipCachedAssetsProtocol) -> CustomDisplayAdapter?
    ) {
        self.displayAdapterFactory.setAdapterFactoryBlock(
            forType: type,
            factoryBlock: factoryBlock
        )
    }
}
