/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Airship rendering engine.
/// - Note: for internal use only.  :nodoc:
public final class Thomas {

    #if !os(watchOS)
    @MainActor
    @discardableResult
    public class func display(
        layout: AirshipLayout,
        scene: UIWindowScene,
        extensions: ThomasExtensions? = nil,
        delegate: ThomasDelegate,
        extras: AirshipJSON?,
        priority: Int
    ) throws -> AirshipMainActorCancellable {
        switch layout.presentation {
        case .banner(let presentation):
            return try displayBanner(
                presentation,
                scene: scene,
                layout: layout,
                extensions: extensions,
                delegate: delegate
            )
        case .modal(let presentation):
            return displayModal(
                presentation,
                scene: scene,
                layout: layout,
                extensions: extensions,
                delegate: delegate
            )
        case .embedded(let presentation):
            return AirshipEmbeddedViewManager.shared.addPending(
                presentation: presentation,
                layout: layout,
                extensions: extensions,
                delegate: delegate,
                extras: extras,
                priority: priority
            )
        }
    }

    @MainActor
    private class func displayBanner(
        _ presentation: ThomasPresentationInfo.Banner,
        scene: UIWindowScene,
        layout: AirshipLayout,
        extensions: ThomasExtensions?,
        delegate: ThomasDelegate
    ) throws -> AirshipMainActorCancellable {
        guard let window = AirshipUtils.mainWindow(scene: scene),
            window.rootViewController != nil
        else {
            throw AirshipErrors.error("Failed to find window")
        }

        var viewController: ThomasBannerViewController?
        let holder = AirshipStrongValueHolder<UIViewController>()

        let dismissController = {
            holder.value?.view.removeFromSuperview()
            holder.value?.removeFromParent()
            holder.value = nil
        }

        let options = ThomasViewControllerOptions()
        let environment = ThomasEnvironment(
            delegate: delegate,
            extensions: extensions
        )

        let bannerConstraints = ThomasBannerConstraints(
            size: windowSize(window)
        )

        let rootView = BannerView(
            viewControllerOptions: options,
            presentation: presentation,
            layout: layout,
            thomasEnvironment: environment,
            bannerConstraints: bannerConstraints,
            onDismiss: dismissController
        )

        viewController = ThomasBannerViewController(
            window: window,
            rootView: rootView,
            options: options,
            constraints: bannerConstraints
        )

        holder.value = viewController
        
        if let view = viewController?.view {
            view.willMove(toWindow: window)
            window.addSubview(view)
            view.didMoveToWindow()
        }

        return AirshipMainActorCancellableBlock { [weak environment] in
            environment?.dismiss()
        }
    }

    @MainActor
    private class func displayModal(
        _ presentation: ThomasPresentationInfo.Modal,
        scene: UIWindowScene,
        layout: AirshipLayout,
        extensions: ThomasExtensions?,
        delegate: ThomasDelegate
    ) -> AirshipMainActorCancellable {
        let window: UIWindow = UIWindow.airshipMakeModalReadyWindow(scene: scene)
        var viewController: ThomasModalViewController?

        let options = ThomasViewControllerOptions()
        options.orientation = presentation.defaultPlacement.device?.orientationLock

        let environment = ThomasEnvironment(
            delegate: delegate,
            extensions: extensions
        ) {
            window.airshipAnimateOut()
        }

        let rootView = ModalView(
            presentation: presentation,
            layout: layout,
            thomasEnvironment: environment,
            viewControllerOptions: options
        )
        viewController = ThomasModalViewController(
            rootView: rootView,
            options: options
        )
        viewController?.modalPresentationStyle = .currentContext
        window.rootViewController = viewController
        window.airshipAnimateIn()

        return AirshipMainActorCancellableBlock { [weak environment] in
            environment?.dismiss()
        }
    }

    @MainActor
    private class func windowSize(_ window: UIWindow) -> CGSize {
        #if os(iOS) || os(tvOS)
        return window.screen.bounds.size
        #elseif os(visionOS)
        // https://developer.apple.com/design/human-interface-guidelines/windows#visionOS
        return CGSize(
            width: 1280,
            height: 720
        )
        #elseif os(watchOS)
        return CGSize(
            width: WKInterfaceDevice.current().screenBounds.width,
            height: WKInterfaceDevice.current().screenBounds.height
        )
        #endif
    }
    #endif
}

/// Airship rendering engine extensions.
/// - Note: for internal use only.  :nodoc:
public struct ThomasExtensions {

    #if !os(tvOS) && !os(watchOS)
    var nativeBridgeExtension: NativeBridgeExtensionDelegate?
    #endif

    var imageProvider: AirshipImageProvider?

    var actionRunner: ThomasActionRunner?

    #if os(tvOS) || os(watchOS)
    public init(
        imageProvider: AirshipImageProvider? = nil,
        actionRunner: ThomasActionRunner? = nil
    ) {
        self.imageProvider = imageProvider
    }
    #else

    public init(
        nativeBridgeExtension: NativeBridgeExtensionDelegate? = nil,
        imageProvider: AirshipImageProvider? = nil,
        actionRunner: ThomasActionRunner? = nil
    ) {
        self.nativeBridgeExtension = nativeBridgeExtension
        self.imageProvider = imageProvider
        self.actionRunner = actionRunner
    }
    #endif
}

/// Thomas action runner
/// - Note: for internal use only.  :nodoc:
public protocol ThomasActionRunner: Sendable {
    @MainActor
    func runAsync(actions: AirshipJSON, layoutContext: ThomasLayoutContext?)

    @MainActor
    func run(actionName: String, arguments: ActionArguments, layoutContext: ThomasLayoutContext?) async -> ActionResult
}


