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
        displayTarget: AirshipDisplayTarget,
        extensions: ThomasExtensions? = nil,
        delegate: any ThomasDelegate,
        extras: AirshipJSON?,
        priority: Int
    ) throws -> any AirshipMainActorCancellable {
        switch layout.presentation {
        case .banner(let presentation):
            return try displayBanner(
                presentation,
                displayTarget: displayTarget,
                layout: layout,
                extensions: extensions,
                delegate: delegate
            )
        case .modal(let presentation):
            return try displayModal(
                presentation,
                displayTarget: displayTarget,
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
        displayTarget: AirshipDisplayTarget,
        layout: AirshipLayout,
        extensions: ThomasExtensions?,
        delegate: any ThomasDelegate
    ) throws -> any AirshipMainActorCancellable {
        let displayable = displayTarget.prepareDisplay(for: .banner)

        let options = ThomasViewControllerOptions()
        let environment = ThomasEnvironment(
            delegate: delegate,
            extensions: extensions
        )

        try displayable.display { windowInfo in
            let bannerConstraints = ThomasBannerConstraints(
                windowSize: windowInfo.size
            )

            let rootView = BannerView(
                viewControllerOptions: options,
                presentation: presentation,
                layout: layout,
                thomasEnvironment: environment,
                bannerConstraints: bannerConstraints,
            ) {
                displayable.dismiss()
            }

            return ThomasBannerViewController(
                rootView: rootView,
                position: presentation.defaultPlacement.position,
                options: options,
                constraints: bannerConstraints
            )
        }

        return AirshipMainActorCancellableBlock { [weak environment] in
            environment?.dismiss()
        }
    }

    @MainActor
    private class func displayModal(
        _ presentation: ThomasPresentationInfo.Modal,
        displayTarget: AirshipDisplayTarget,
        layout: AirshipLayout,
        extensions: ThomasExtensions?,
        delegate: any ThomasDelegate
    ) throws -> any AirshipMainActorCancellable {
        let displayable = displayTarget.prepareDisplay(for: .modal)

        let options = ThomasViewControllerOptions()
        options.orientation = presentation.defaultPlacement.device?.orientationLock

        let environment = ThomasEnvironment(
            delegate: delegate,
            extensions: extensions
        ) {
            displayable.dismiss()
        }

        let rootView = ModalView(
            presentation: presentation,
            layout: layout,
            thomasEnvironment: environment,
            viewControllerOptions: options
        )

        try displayable.display { window in
            return ThomasModalViewController(
                rootView: rootView,
                options: options
            )
        }

        return AirshipMainActorCancellableBlock { [weak environment] in
            environment?.dismiss()
        }
    }

    #endif
}

/// Airship rendering engine extensions.
/// - Note: for internal use only.  :nodoc:
public struct ThomasExtensions {

    #if !os(tvOS) && !os(watchOS)
    var nativeBridgeExtension: (any NativeBridgeExtensionDelegate)?
    #endif

    var imageProvider: (any AirshipImageProvider)?

    var actionRunner: (any ThomasActionRunner)?

    #if os(tvOS) || os(watchOS)
    public init(
        imageProvider: (any AirshipImageProvider)? = nil,
        actionRunner: (any ThomasActionRunner)? = nil
    ) {
        self.imageProvider = imageProvider
    }
    #else

    public init(
        nativeBridgeExtension: (any NativeBridgeExtensionDelegate)? = nil,
        imageProvider: (any AirshipImageProvider)? = nil,
        actionRunner: (any ThomasActionRunner)? = nil
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
    func runAsync(actions: AirshipJSON, layoutContext: ThomasLayoutContext)

    @MainActor
    func run(actionName: String, arguments: ActionArguments, layoutContext: ThomasLayoutContext) async -> ActionResult
}


