/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// In-app messaging
public protocol InAppMessaging: AnyObject, Sendable {

    /// Called when the Message  is requested to be displayed.
    /// Return `true` if the message is ready to display,  `false`  otherwise.
    @MainActor
    var onIsReadyToDisplay: (@MainActor @Sendable (_ message: InAppMessage, _ scheduleID: String) -> Bool)? { get set }
    
    /// Theme manager
    @MainActor
    var themeManager: InAppAutomationThemeManager { get }

    /// Display interval
    @MainActor
    var displayInterval: TimeInterval { get set }

    /// Display delegate
    @MainActor
    var displayDelegate: (any InAppMessageDisplayDelegate)? { get set }

    /// Scene delegate
    @MainActor
    var sceneDelegate: (any InAppMessageSceneDelegate)? { get set }

    /// Sets a factory block for a custom display adapter.
    /// If the factory block returns a nil adapter, the default adapter will be used.
    ///
    /// - Parameters:
    ///     - forType: The type
    ///     - factoryBlock: The factory block
    @MainActor
    func setCustomAdapter(
        forType: CustomDisplayAdapterType,
        factoryBlock: @escaping @Sendable (DisplayAdapterArgs) -> (any CustomDisplayAdapter)?
    )

    /// Notifies In-App messages that the display conditions should be reevaluated.
    /// This should only be called when state that was used to prevent a display with  `InAppMessageDisplayDelegate` changes.
    @MainActor
    func notifyDisplayConditionsChanged()
}

final class DefaultInAppMessaging: InAppMessaging {
    
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
    var onIsReadyToDisplay: (@MainActor @Sendable (InAppMessage, String) -> Bool)? {
        get {
            return executor.onIsReadyToDisplay
        }
        set {
            executor.onIsReadyToDisplay = newValue
        }
    }
    
    @MainActor
    weak var displayDelegate: (any InAppMessageDisplayDelegate)? {
        get {
            return executor.displayDelegate
        }
        set {
            executor.displayDelegate = newValue
        }
    }

    @MainActor
    weak var sceneDelegate: (any InAppMessageSceneDelegate)? {
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
        factoryBlock: @escaping @Sendable (InAppMessage, any AirshipCachedAssetsProtocol) -> (any CustomDisplayAdapter)?
    ) {
        self.setCustomAdapter(forType: type) { args in
            factoryBlock(args.message, args.assets)
        }
    }

    @MainActor
    func setCustomAdapter(
        forType type: CustomDisplayAdapterType,
        factoryBlock: @escaping @Sendable (DisplayAdapterArgs) -> (any CustomDisplayAdapter)?
    ) {
        self.preparer.setAdapterFactoryBlock(forType: type, factoryBlock: factoryBlock)
    }

    @MainActor
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
