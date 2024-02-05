/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Airship rendering engine.
/// - Note: for internal use only.  :nodoc:
public class Thomas: NSObject {

    private static let decoder = JSONDecoder()
    static let minLayoutVersion = 1
    static let maxLayoutVersion = 2

    class func decode(_ json: Data) throws -> AirshipLayout {
        let layout = try self.decoder.decode(AirshipLayout.self, from: json)
        return layout
    }

    public class func validate(data: Data) throws {
        let layout = try decode(data)

        guard
            layout.version >= minLayoutVersion
                && layout.version <= maxLayoutVersion
        else {
            throw AirshipErrors.error(
                "Unable to process layout with version \(layout.version)"
            )
        }

        try layout.validate()
    }

    public class func validate(json: Any) throws {
        let data = try JSONSerialization.data(withJSONObject: json, options: [])
        try validate(data: data)
    }

    public class func urls(json: Any) throws -> [URLInfo] {
        let data = try JSONSerialization.data(withJSONObject: json, options: [])
        return try decode(data).urlInfos
    }

    #if !os(watchOS)
    @MainActor
    public class func deferredDisplay(
        json: Any,
        scene: () -> UIWindowScene?,
        extensions: ThomasExtensions? = nil,
        delegate: ThomasDelegate
    ) throws -> () -> Disposable {
        let data = try JSONSerialization.data(
            withJSONObject: json,
            options: []
        )
        return try deferredDisplay(
            data: data,
            scene: scene,
            extensions: extensions,
            delegate: delegate
        )
    }

    @MainActor
    public class func display(
        layout: AirshipLayout,
        scene: UIWindowScene,
        extensions: ThomasExtensions? = nil,
        delegate: ThomasDelegate
    ) throws {
        switch layout.presentation {
        case .banner(let presentation):
            _ = try bannerDisplay(
                presentation,
                scene: scene,
                layout: layout,
                extensions: extensions,
                delegate: delegate
            )()
        case .modal(let presentation):
            _ = modalDisplay(
                presentation,
                scene: scene,
                layout: layout,
                extensions: extensions,
                delegate: delegate
            )()
        case .embedded(let presentation):
            AirshipEmbeddedViewManager.shared.addPending(
                presentation: presentation, layout: layout, extensions: extensions, delegate: delegate
            )
        }
    }

    @discardableResult
    @MainActor
    public class func deferredDisplay(
        data: Data,
        scene: () -> UIWindowScene?,
        extensions: ThomasExtensions? = nil,
        delegate: ThomasDelegate
    ) throws -> () -> Disposable {
        let layout = try decode(data)

        switch layout.presentation {
        case .banner(let presentation):
            guard let scene = scene() else {
                throw AirshipErrors.error("Unable to get scene")
            }
            return try bannerDisplay(
                presentation,
                scene: scene,
                layout: layout,
                extensions: extensions,
                delegate: delegate
            )
        case .modal(let presentation):
            guard let scene = scene() else {
                throw AirshipErrors.error("Unable to get scene")
            }
            return modalDisplay(
                presentation,
                scene: scene,
                layout: layout,
                extensions: extensions,
                delegate: delegate
            )
        case .embedded(let presentation):
            return {
                AirshipEmbeddedViewManager.shared.addPending(
                    presentation: presentation, layout: layout, extensions: extensions, delegate: delegate
                )
                return Disposable {
                }
            }
        }
    }

    @MainActor
    @discardableResult
    public class func display(
        _ data: Data,
        scene: () -> UIWindowScene?,
        extensions: ThomasExtensions? = nil,
        delegate: ThomasDelegate
    ) throws -> Disposable {
        return try deferredDisplay(
            data: data,
            scene: scene,
            extensions: extensions,
            delegate: delegate
        )()
    }

    @MainActor
    private class func bannerDisplay(
        _ presentation: BannerPresentationModel,
        scene: UIWindowScene,
        layout: AirshipLayout,
        extensions: ThomasExtensions?,
        delegate: ThomasDelegate
    ) throws -> () -> Disposable {

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

        return {
            if let viewController = viewController,
                let rootController = window.rootViewController
            {
                rootController.addChild(viewController)
                viewController.didMove(toParent: rootController)
                rootController.view.addSubview(viewController.view)
            }

            return Disposable {
                environment.dismiss()
            }
        }
    }

    @MainActor
    private class func modalDisplay(
        _ presentation: ModalPresentationModel,
        scene: UIWindowScene,
        layout: AirshipLayout,
        extensions: ThomasExtensions?,
        delegate: ThomasDelegate
    ) -> () -> Disposable {

        let window: UIWindow = UIWindow(windowScene: scene)
        window.accessibilityViewIsModal = true
        var viewController: ThomasModalViewController?

        let options = ThomasViewControllerOptions()
        options.orientation = presentation.defaultPlacement.device?.orientationLock

        let environment = ThomasEnvironment(
            delegate: delegate,
            extensions: extensions
        ) { [weak window] in
            window?.isHidden = true
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

        return { [weak window] in
            window?.makeKeyAndVisible()

            return Disposable {
                environment.dismiss()
            }
        }
    }

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
public class ThomasExtensions: NSObject {

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

public enum UrlTypes: Int {
    case image
    case video
    case web
}


