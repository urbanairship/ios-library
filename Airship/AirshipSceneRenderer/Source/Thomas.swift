/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
@_spi(AirshipInternal) public import AirshipBasement
public import AirshipCore

/// Airship rendering engine.
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public final class Thomas {

    #if !os(watchOS)
    @MainActor
    @discardableResult
    public class func display(
        layout: AirshipLayout,
        displayTarget: AirshipDisplayTarget,
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
                delegate: delegate
            )
        case .modal(let presentation):
            return try displayModal(
                presentation,
                displayTarget: displayTarget,
                layout: layout,
                delegate: delegate
            )
        case .embedded(let presentation):
            return AirshipEmbeddedViewManager.shared.addPending(
                presentation: presentation,
                layout: layout,
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
        delegate: any ThomasDelegate
    ) throws -> any AirshipMainActorCancellable {
        let displayable = displayTarget.prepareDisplay(for: .banner)

        let options = ThomasViewControllerOptions()
        let environment = ThomasEnvironment(
            delegate: delegate
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
        delegate: any ThomasDelegate
    ) throws -> any AirshipMainActorCancellable {
        let displayable = displayTarget.prepareDisplay(for: .modal, windowAnimated: false)

        let options = ThomasViewControllerOptions()
        options.orientation = presentation.defaultPlacement.device?.orientationLock

        let environment = ThomasEnvironment(
            delegate: delegate
        )

        let rootView = ModalView(
            presentation: presentation,
            layout: layout,
            thomasEnvironment: environment,
            viewControllerOptions: options
        ) {
            displayable.dismiss()
        }

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

/// Thomas action runner
/// - Note: For internal use only. :nodoc:
public protocol ThomasActionRunner: Sendable {
    @MainActor
    func runAsync(actions: AirshipJSON, layoutContext: ThomasLayoutContext)

    @MainActor
    func run(actionName: String, arguments: ActionArguments, layoutContext: ThomasLayoutContext) async -> ActionResult
}


