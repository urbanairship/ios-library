/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Display adapter args
public struct DisplayAdapterArgs: Sendable {
    /// The in-app message
    public var message: InAppMessage

    /// The assets
    public var assets: AirshipCachedAssetsProtocol

    /// The schedule priority
    public var priority: Int

    /// Action runner
    public var actionRunner: InAppActionRunner {
        return _actionRunner
    }
    
    var _actionRunner: InternalInAppActionRunner
}

protocol DisplayAdapterFactoryProtocol: Sendable {

    @MainActor
    func setAdapterFactoryBlock(
        forType: CustomDisplayAdapterType,
        factoryBlock: @Sendable @escaping (DisplayAdapterArgs) -> CustomDisplayAdapter?
    )

    @MainActor
    func makeAdapter(
        args: DisplayAdapterArgs
    ) throws -> DisplayAdapter
}

final class DisplayAdapterFactory: DisplayAdapterFactoryProtocol, @unchecked Sendable {

    @MainActor
    var customAdapters: [CustomDisplayAdapterType: (DisplayAdapterArgs) -> CustomDisplayAdapter?] = [:]

    @MainActor
    func setAdapterFactoryBlock(
        forType type: CustomDisplayAdapterType,
        factoryBlock: @Sendable @escaping (DisplayAdapterArgs) -> CustomDisplayAdapter?
    ) {
        customAdapters[type] = factoryBlock
    }

    @MainActor
    func makeAdapter(
        args: DisplayAdapterArgs
    ) throws -> DisplayAdapter {
        switch (args.message.displayContent) {
        case .banner(_):
            if let custom = customAdapters[.banner]?(args) {
                return CustomDisplayAdapterWrapper(adapter: custom)
            }
        case .fullscreen(_):
            if let custom = customAdapters[.fullscreen]?(args) {
                return CustomDisplayAdapterWrapper(adapter: custom)
            }
        case .modal(_):
            if let custom = customAdapters[.modal]?(args) {
                return CustomDisplayAdapterWrapper(adapter: custom)
            }
        case .html(_):
            if let custom = customAdapters[.html]?(args) {
                return CustomDisplayAdapterWrapper(adapter: custom)
            }
        case .custom(_):
            if let custom = customAdapters[.custom]?(args) {
                return CustomDisplayAdapterWrapper(adapter: custom)
            } else {
                throw AirshipErrors.error("No adapter for message: \(args.message)")
            }
        case .airshipLayout(_):
            break
        }

        return try AirshipLayoutDisplayAdapter(
            message: args.message,
            priority: args.priority,
            assets: args.assets,
            actionRunner: args._actionRunner
        )
    }
}


