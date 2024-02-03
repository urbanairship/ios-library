/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// In-App messaging
public protocol InAppMessagingProtocol: AnyObject, Sendable {
    /// Display interval
    @MainActor
    var displayInterval: TimeInterval { get set }

    /// Display delegate
    @MainActor
    var displayDelegate: InAppMessageDisplayDelegate? { get set }

    /// Scene delegate
    @MainActor
    var sceneDelegate: InAppMessageSceneDelegate? { get set }

    /// Sets a factory block for a custom display adapter.
    /// If the factory block returns a nil adapter, the default adapter will be used.
    ///
    /// - Parameters:
    ///     - forType: The type
    ///     - factoryBlock: The factory block
    @MainActor
    func setAdapterFactoryBlock(
        forType: CustomDisplayAdapterType,
        factoryBlock: @escaping @Sendable (InAppMessage, AirshipCachedAssetsProtocol) -> CustomDisplayAdapter?
    )
}

final class InAppMessaging: InAppMessagingProtocol {
    let executor: InAppMessageAutomationExecutor
    let preparer: InAppMessageAutomationPreparer

    @MainActor
    public var displayInterval: TimeInterval {
        get {
            return preparer.displayInterval
        }
        set {
            preparer.displayInterval = newValue
        }
    }

    @MainActor
    public weak var displayDelegate: InAppMessageDisplayDelegate? {
        get {
            return executor.displayDelegate
        }
        set {
            executor.displayDelegate = newValue
        }
    }

    @MainActor
    public weak var sceneDelegate: InAppMessageSceneDelegate? {
        get {
            return executor.sceneDelegate
        }
        set {
            executor.sceneDelegate = newValue
        }
    }

    @MainActor
    func setAdapterFactoryBlock(
        forType type: CustomDisplayAdapterType,
        factoryBlock: @escaping @Sendable (InAppMessage, AirshipCachedAssetsProtocol) -> CustomDisplayAdapter?
    ) {
        self.preparer.setAdapterFactoryBlock(forType: type, factoryBlock: factoryBlock)
    }

    init(
        executor: InAppMessageAutomationExecutor,
        preparer: InAppMessageAutomationPreparer
    ) {
        self.executor = executor
        self.preparer = preparer
    }
}
