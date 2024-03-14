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
        extras: AirshipJSON?
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
                extras: extras
            )
        }
    }

    @MainActor
    private class func displayBanner(
        _ presentation: BannerPresentationModel,
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

        let dismissController = {
            viewController?.view.removeFromSuperview()
            viewController = nil
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
            rootView: rootView,
            options: options,
            constraints: bannerConstraints
        )

        if let viewController = viewController,
            let rootController = window.rootViewController
        {
            rootController.addChild(viewController)
            viewController.didMove(toParent: rootController)
            rootController.view.addSubview(viewController.view)
        }
        return AirshipMainActorCancellableBlock { [weak environment] in
            environment?.dismiss()
        }
    }

    @MainActor
    private class func displayModal(
        _ presentation: ModalPresentationModel,
        scene: UIWindowScene,
        layout: AirshipLayout,
        extensions: ThomasExtensions?,
        delegate: ThomasDelegate
    ) -> AirshipMainActorCancellable {

        let window: UIWindow = UIWindow(windowScene: scene)
        window.accessibilityViewIsModal = true
        var viewController: ThomasModalViewController?

        let options = ThomasViewControllerOptions()
        options.orientation = presentation.defaultPlacement.device?.orientationLock

        let environment = ThomasEnvironment(
            delegate: delegate,
            extensions: extensions
        ) {
            window.isHidden = true
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
        window.makeKeyAndVisible()

        return AirshipMainActorCancellableBlock { [environment] in
            environment.dismiss()
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
    let nativeBridgeExtension: NativeBridgeExtensionDelegate?
    #endif

    let imageProvider: AirshipImageProvider?

    #if os(tvOS) || os(watchOS)
    public init(imageProvider: AirshipImageProvider? = nil) {
        self.imageProvider = imageProvider
    }
    #else

    public init(
        nativeBridgeExtension: NativeBridgeExtensionDelegate? = nil,
        imageProvider: AirshipImageProvider? = nil
    ) {
        self.nativeBridgeExtension = nativeBridgeExtension
        self.imageProvider = imageProvider
    }
    #endif
}



