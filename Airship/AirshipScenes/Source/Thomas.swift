/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
@_spi(AirshipInternal) public import AirshipBasement
@_spi(AirshipInternal) public import AirshipSceneRenderer
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
        extensions: any ThomasExtensions,
        extras: AirshipJSON?,
        priority: Int
    ) throws -> any AirshipMainActorCancellable {
        switch layout.presentation {
        case .banner(let presentation):
            return try displayBanner(
                presentation,
                displayTarget: displayTarget,
                layout: layout,
                delegate: delegate,
                extensions: extensions
            )
        case .modal(let presentation):
            return try displayModal(
                presentation,
                displayTarget: displayTarget,
                layout: layout,
                delegate: delegate,
                extensions: extensions
            )
        case .embedded(let presentation):
            return AirshipEmbeddedViewManager.shared.addPending(
                presentation: presentation,
                layout: layout,
                delegate: delegate,
                extras: extras,
                priority: priority,
                extensions: extensions
            )
        }
    }

    @MainActor
    private class func displayBanner(
        _ presentation: ThomasPresentationInfo.Banner,
        displayTarget: AirshipDisplayTarget,
        layout: AirshipLayout,
        delegate: any ThomasDelegate,
        extensions: any ThomasExtensions
    ) throws -> any AirshipMainActorCancellable {
        let displayable = displayTarget.prepareDisplay(for: .banner)

        var dismiss: (@MainActor @Sendable () -> Void)?
        try displayable.display { windowInfo in
#if !os(macOS)
            let windowScene = ThomasWindowScene(try? displayTarget.sceneProvider())
#else
            let windowScene = ThomasWindowScene()
#endif
            let made = ThomasViewControllerFactory.makeBannerViewController(
                presentation: presentation,
                layout: layout,
                delegate: delegate,
                windowScene: windowScene,
                extensions: extensions,
                windowSize: windowInfo.size,
                onDismiss: { displayable.dismiss() }
            )
            dismiss = made.dismiss
            return made.viewController
        }

        let resolvedDismiss = dismiss
        return AirshipMainActorCancellableBlock { resolvedDismiss?() }
    }

    @MainActor
    private class func displayModal(
        _ presentation: ThomasPresentationInfo.Modal,
        displayTarget: AirshipDisplayTarget,
        layout: AirshipLayout,
        delegate: any ThomasDelegate,
        extensions: any ThomasExtensions
    ) throws -> any AirshipMainActorCancellable {
        let displayable = displayTarget.prepareDisplay(for: .modal, windowAnimated: false)

        var dismiss: (@MainActor @Sendable () -> Void)?
        try displayable.display { _ in
#if !os(macOS)
            let windowScene = ThomasWindowScene(try? displayTarget.sceneProvider())
#else
            let windowScene = ThomasWindowScene()
#endif
            let made = ThomasViewControllerFactory.makeModalViewController(
                presentation: presentation,
                layout: layout,
                delegate: delegate,
                windowScene: windowScene,
                extensions: extensions,
                onDismiss: { displayable.dismiss() }
            )
            dismiss = made.dismiss
            return made.viewController
        }

        let resolvedDismiss = dismiss
        return AirshipMainActorCancellableBlock { resolvedDismiss?() }
    }

    #endif
}



