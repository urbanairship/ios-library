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
        windowScene: ThomasWindowScene = ThomasWindowScene(),
        extensions: any ThomasExtensions,
        windowSize: CGSize,
        onDismiss: @escaping @MainActor () -> Void
    ) -> (viewController: AirshipNativeViewController, dismiss: @MainActor @Sendable () -> Void) {
        let environment = ThomasEnvironment(delegate: delegate, windowScene: windowScene, extensions: extensions)
        let bannerConstraints = ThomasBannerConstraints(windowSize: windowSize)

        let rootView = BannerView(
            presentation: presentation,
            layout: layout,
            thomasEnvironment: environment,
            bannerConstraints: bannerConstraints
        ) {
            onDismiss()
        }

#if os(macOS)
        // The macOS variant positions the banner itself and still needs the position
        let viewController = ThomasBannerViewController(
            rootView: rootView,
            position: presentation.defaultPlacement.position,
            constraints: bannerConstraints
        )
#else
        let viewController = ThomasBannerViewController(
            rootView: rootView,
            constraints: bannerConstraints
        )
#endif

        return (viewController, { [weak environment] in environment?.dismiss() })
    }

    @MainActor
    @_spi(AirshipInternal)
    public static func makeModalViewController(
        presentation: ThomasPresentationInfo.Modal,
        layout: AirshipLayout,
        delegate: any ThomasDelegate,
        windowScene: ThomasWindowScene = ThomasWindowScene(),
        extensions: any ThomasExtensions,
        windowSize: CGSize,
        onDismiss: @escaping @MainActor () -> Void
    ) -> (viewController: AirshipNativeViewController, dismiss: @MainActor @Sendable () -> Void) {
        let environment = ThomasEnvironment(delegate: delegate, windowScene: windowScene, extensions: extensions)

        let rootView = ModalView(
            presentation: presentation,
            layout: layout,
            thomasEnvironment: environment,
            initialWindowSize: windowSize
        ) {
            onDismiss()
        }

        let viewController = ThomasModalViewController(
            rootView: rootView
        )

        return (viewController, { [weak environment] in environment?.dismiss() })
    }
    #endif
}
