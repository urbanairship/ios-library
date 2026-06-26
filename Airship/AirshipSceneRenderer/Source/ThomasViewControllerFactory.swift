/* Copyright Airship and Contributors */

public import Foundation
public import AirshipBasement

#if canImport(UIKit)
public import UIKit
#elseif canImport(AppKit)
public import AppKit
#endif

/// Builds Thomas view controllers from layout inputs, independent of how or where
/// they are presented. Core-free: depends only on the renderer's own view layer.
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public struct ThomasViewControllerFactory {

    #if !os(watchOS)
    @MainActor
    @_spi(AirshipInternal)
    public static func makeBannerViewController(
        presentation: ThomasPresentationInfo.Banner,
        layout: AirshipLayout,
        delegate: any ThomasDelegate,
        windowSize: CGSize,
        onDismiss: @escaping @MainActor () -> Void
    ) -> (viewController: AirshipNativeViewController, dismiss: @MainActor @Sendable () -> Void) {
        let options = ThomasViewControllerOptions()
        let environment = ThomasEnvironment(delegate: delegate)
        let bannerConstraints = ThomasBannerConstraints(windowSize: windowSize)

        let rootView = BannerView(
            viewControllerOptions: options,
            presentation: presentation,
            layout: layout,
            thomasEnvironment: environment,
            bannerConstraints: bannerConstraints
        ) {
            onDismiss()
        }

        let viewController = ThomasBannerViewController(
            rootView: rootView,
            position: presentation.defaultPlacement.position,
            options: options,
            constraints: bannerConstraints
        )

        return (viewController, { [weak environment] in environment?.dismiss() })
    }

    @MainActor
    @_spi(AirshipInternal)
    public static func makeModalViewController(
        presentation: ThomasPresentationInfo.Modal,
        layout: AirshipLayout,
        delegate: any ThomasDelegate,
        onDismiss: @escaping @MainActor () -> Void
    ) -> (viewController: AirshipNativeViewController, dismiss: @MainActor @Sendable () -> Void) {
        let options = ThomasViewControllerOptions()
        options.orientation = presentation.defaultPlacement.device?.orientationLock
        let environment = ThomasEnvironment(delegate: delegate)

        let rootView = ModalView(
            presentation: presentation,
            layout: layout,
            thomasEnvironment: environment,
            viewControllerOptions: options
        ) {
            onDismiss()
        }

        let viewController = ThomasModalViewController(
            rootView: rootView,
            options: options
        )

        return (viewController, { [weak environment] in environment?.dismiss() })
    }
    #endif
}
