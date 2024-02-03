/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

protocol DisplayAdapterFactoryProtocol: Sendable {

    @MainActor
    func setAdapterFactoryBlock(
        forType: CustomDisplayAdapterType,
        factoryBlock: @Sendable @escaping (InAppMessage, AirshipCachedAssetsProtocol) -> CustomDisplayAdapter?
    )

    @MainActor
    func makeAdapter(
        message: InAppMessage,
        assets: AirshipCachedAssetsProtocol
    ) throws -> DisplayAdapter
}

final class DisplayAdapterFactory: DisplayAdapterFactoryProtocol, @unchecked Sendable {

    @MainActor
    var customAdapters: [CustomDisplayAdapterType: (InAppMessage, AirshipCachedAssetsProtocol) -> CustomDisplayAdapter?] = [:]

    @MainActor
    func setAdapterFactoryBlock(
        forType type: CustomDisplayAdapterType,
        factoryBlock: @Sendable @escaping (InAppMessage, AirshipCachedAssetsProtocol) -> CustomDisplayAdapter?
    ) {
        customAdapters[type] = factoryBlock
    }

    @MainActor
    func makeAdapter(
        message: InAppMessage,
        assets: AirshipCachedAssetsProtocol
    ) throws -> DisplayAdapter {
        switch (message.displayContent) {
        case .banner(_):
            if let custom = customAdapters[.banner]?(message, assets) {
                return CustomDisplayAdapterWrapper(adapter: custom)
            }
        case .fullscreen(_):
            if let custom = customAdapters[.fullscreen]?(message, assets) {
                return CustomDisplayAdapterWrapper(adapter: custom)
            }
        case .modal(_):
            if let custom = customAdapters[.modal]?(message, assets) {
                return CustomDisplayAdapterWrapper(adapter: custom)
            }
        case .html(_):
            if let custom = customAdapters[.html]?(message, assets) {
                return CustomDisplayAdapterWrapper(adapter: custom)
            }
        case .custom(_):
            if let custom = customAdapters[.custom]?(message, assets) {
                return CustomDisplayAdapterWrapper(adapter: custom)
            } else {
                throw AirshipErrors.error("No adapter for message: \(message)")
            }
        case .airshipLayout(_):
            break
        }

        return try AirshipLayoutDisplayAdapter(message: message, assets: assets)
    }
}


