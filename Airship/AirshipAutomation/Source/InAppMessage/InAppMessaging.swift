/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// In-app messaging
public protocol InAppMessagingProtocol: AnyObject, Sendable {

    /// Theme manager
    @MainActor
    var themeManager: InAppAutomationThemeManager { get }

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
    @available(*, deprecated, message: "Use setCustomAdapter(forType:factoryBlock:) instead")
    func setAdapterFactoryBlock(
        forType: CustomDisplayAdapterType,
        factoryBlock: @escaping @Sendable (InAppMessage, AirshipCachedAssetsProtocol) -> CustomDisplayAdapter?
    )

    /// Sets a factory block for a custom display adapter.
    /// If the factory block returns a nil adapter, the default adapter will be used.
    ///
    /// - Parameters:
    ///     - forType: The type
    ///     - factoryBlock: The factory block
    @MainActor
    func setCustomAdapter(
        forType: CustomDisplayAdapterType,
        factoryBlock: @escaping @Sendable (DisplayAdapterArgs) -> CustomDisplayAdapter?
    )

    /// Notifies In-App messages that the display conditions should be reevaluated.
    /// This should only be called when state that was used to prevent a display with  `InAppMessageDisplayDelegate` changes.
    @MainActor
    func notifyDisplayConditionsChanged()
}

final class InAppMessaging: InAppMessagingProtocol {
    let executor: InAppMessageAutomationExecutor
    let preparer: InAppMessageAutomationPreparer

    @MainActor
    let themeManager: InAppAutomationThemeManager = InAppAutomationThemeManager()

    @MainActor
    var displayInterval: TimeInterval {
        get {
            return preparer.displayInterval
        }
        set {
            preparer.displayInterval = newValue
        }
    }

    @MainActor
    weak var displayDelegate: InAppMessageDisplayDelegate? {
        get {
            return executor.displayDelegate
        }
        set {
            executor.displayDelegate = newValue
        }
    }

    @MainActor
    weak var sceneDelegate: InAppMessageSceneDelegate? {
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
        self.setCustomAdapter(forType: type) { args in
            factoryBlock(args.message, args.assets)
        }
    }

    @MainActor
    func setCustomAdapter(
        forType type: CustomDisplayAdapterType,
        factoryBlock: @escaping @Sendable (DisplayAdapterArgs) -> CustomDisplayAdapter?
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

    @MainActor
    func notifyDisplayConditionsChanged() {
        executor.notifyDisplayConditionsChanged()
    }
}
