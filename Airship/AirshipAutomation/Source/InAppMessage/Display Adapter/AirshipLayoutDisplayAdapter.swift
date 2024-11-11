/* Copyright Airship and Contributors */

import Foundation
import UIKit

#if canImport(AirshipCore)
import AirshipCore
#endif

final class AirshipLayoutDisplayAdapter: DisplayAdapter {

    private let message: InAppMessage
    private let priority: Int
    private let assets: AirshipCachedAssetsProtocol
    private let actionRunner: InternalInAppActionRunner?
    private let networkChecker: AirshipNetworkCheckerProtocol

    @MainActor
    var themeManager: InAppAutomationThemeManager {
        return InAppAutomation.shared.inAppMessaging.themeManager
    }


    init(
        message: InAppMessage,
        priority: Int,
        assets: AirshipCachedAssetsProtocol,
        actionRunner: InternalInAppActionRunner? = nil,
        networkChecker: AirshipNetworkCheckerProtocol = AirshipNetworkChecker.shared
    ) throws {
        self.message = message
        self.priority = priority
        self.assets = assets
        self.actionRunner = actionRunner
        self.networkChecker = networkChecker

        if case .custom(_) = message.displayContent {
            throw AirshipErrors.error("Invalid adapter for layout type")
        }
    }

    var isReady: Bool {
        let urlInfos = message.urlInfos
        let needsNetwork = urlInfos.contains { info in
            switch(info) {
            case .web(url: _, requireNetwork: let requireNetwork):
                if (requireNetwork) {
                    return true
                }
            case .video(url: _, requireNetwork: let requireNetwork):
                if (requireNetwork) {
                    return true
                }
            case .image(url: let url, prefetch: let prefetch):
                if let url = URL(string: url), prefetch, !assets.isCached(remoteURL: url) {
                    return true
                }
#if canImport(AirshipCore)
            @unknown default:
                return true
#endif
            }

            return false
        }

        return needsNetwork ? networkChecker.isConnected : true
    }

    func waitForReady() async {
        guard await !self.isReady else {
            return
        }

        for await isConnected in await networkChecker.connectionUpdates {
            if (isConnected) {
                return
            }
        }
    }

    func display(
        scene: WindowSceneHolder,
        analytics: InAppMessageAnalyticsProtocol
    ) async throws -> DisplayResult {
        switch (message.displayContent) {
        case .banner(let banner):
            return try await displayBanner(
                banner,
                scene: scene.scene,
                analytics: analytics
            )
        case .modal(let modal):
            return await displayModal(
                modal,
                scene: scene.scene,
                analytics: analytics
            )
        case .fullscreen(let fullscreen):
            return await displayFullscreen(
                fullscreen,
                scene: scene.scene,
                analytics: analytics
            )
        case .html(let html):
            return await displayHTML(
                html,
                scene: scene.scene,
                analytics: analytics
            )
        case .airshipLayout(let layout):
            return try await displayThomasLayout(
                layout,
                scene: scene.scene,
                analytics: analytics
            )
        case .custom(_):
            // This should never happen - constructor will throw
            return .finished
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

    private func makeInAppExtensions() -> InAppMessageExtensions {
        InAppMessageExtensions(
            nativeBridgeExtension: InAppMessageNativeBridgeExtension(
                message: message
            ),
            imageProvider: AssetCacheImageProvider(assets: assets),
            actionRunner: actionRunner
        )
    }

    @MainActor
    private func displayBanner(
        _ banner: InAppMessageDisplayContent.Banner,
        scene: UIWindowScene,
        analytics: InAppMessageAnalyticsProtocol
    ) async throws -> DisplayResult {
        return try await withCheckedThrowingContinuation { continuation in
    
            guard let window = AirshipUtils.mainWindow(scene: scene)
            else {
                continuation.resume(
                    throwing: AirshipErrors.error("Failed to find window to display in-app banner")
                )
                return
            }

            let holder = AirshipStrongValueHolder<UIViewController>()
            let dismissViewController = {
                holder.value?.view.removeFromSuperview()
                holder.value?.removeFromParent()
                holder.value = nil
            }
            
            var viewController: InAppMessageBannerViewController?

            let listener = InAppMessageDisplayListener(
                analytics: analytics
            ) { result in
                // Dismiss the In app message banner view controller
                continuation.resume(returning: result)
            }

            let theme = self.themeManager.makeBannerTheme(message: self.message)

            let environment = InAppMessageEnvironment(
                delegate: listener,
                extensions: makeInAppExtensions()
            )

            let bannerConstraints = InAppMessageBannerConstraints(
                size: Self.windowSize(window)
            )

            let rootView = InAppMessageBannerView(
                environment: environment,
                displayContent: banner,
                bannerConstraints: bannerConstraints,
                theme: theme,
                onDismiss: dismissViewController
            )

            viewController = InAppMessageBannerViewController(
                window: window,
                rootView: rootView,
                placement: banner.placement,
                bannerConstraints: bannerConstraints
            )

            holder.value = viewController

            if let view = viewController?.view {
                view.willMove(toWindow: window)
                window.addSubview(view)
                view.didMoveToWindow()
            }
        }
    }


    @MainActor
    private func displayModal(
        _ modal: InAppMessageDisplayContent.Modal,
        scene: UIWindowScene,
        analytics: InAppMessageAnalyticsProtocol
    ) async -> DisplayResult {
        return await withCheckedContinuation { continuation in
            let window = UIWindow.airshipMakeModalReadyWindow(scene: scene)

            let listener = InAppMessageDisplayListener(
                analytics: analytics
            ) { result in
                window.airshipAnimateOut()
                continuation.resume(returning: result)
            }

            let theme = self.themeManager.makeModalTheme(message: self.message)

            let environment = InAppMessageEnvironment(
                delegate: listener,
                extensions: makeInAppExtensions()
            )

            let rootView = InAppMessageRootView(inAppMessageEnvironment: environment) {
                InAppMessageModalView(displayContent: modal, theme: theme)
            }

            let viewController = InAppMessageHostingController(rootView: rootView)
            viewController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
            window.rootViewController = viewController

            window.airshipAnimateIn()
        }
    }

    @MainActor
    private func displayFullscreen(
        _ fullscreen: InAppMessageDisplayContent.Fullscreen,
        scene: UIWindowScene,
        analytics: InAppMessageAnalyticsProtocol
    ) async -> DisplayResult {
        return await withCheckedContinuation { continuation in
            let window = UIWindow.airshipMakeModalReadyWindow(scene: scene)

            let listener = InAppMessageDisplayListener(
                analytics: analytics
            ) { result in
                window.airshipAnimateOut()
                continuation.resume(returning: result)
            }

            let theme = self.themeManager.makeFullscreenTheme(message: self.message)

            let environment = InAppMessageEnvironment(
                delegate: listener,
                extensions: makeInAppExtensions()
            )

            let rootView = InAppMessageRootView(inAppMessageEnvironment: environment) {
                FullscreenView(displayContent: fullscreen, theme: theme)
            }

            let viewController = InAppMessageHostingController(rootView: rootView)
            viewController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
            window.rootViewController = viewController

            window.airshipAnimateIn()
        }
    }

    @MainActor
    private func displayHTML(
        _ html: InAppMessageDisplayContent.HTML,
        scene: UIWindowScene,
        analytics: InAppMessageAnalyticsProtocol
    ) async -> DisplayResult {
        return await withCheckedContinuation { continuation in
            let window = UIWindow.airshipMakeModalReadyWindow(scene: scene)

            let listener = InAppMessageDisplayListener(
                analytics: analytics
            ) { result in
                window.airshipAnimateOut()
                continuation.resume(returning: result)
            }

            let theme = self.themeManager.makeHTMLTheme(message: self.message)

            let environment = InAppMessageEnvironment(
                delegate: listener,
                extensions: makeInAppExtensions()
            )

            let rootView = InAppMessageRootView(inAppMessageEnvironment: environment) {
                HTMLView(displayContent: html, theme: theme)
            }

            let viewController = InAppMessageHostingController(rootView: rootView)
            viewController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
            window.rootViewController = viewController

            window.airshipAnimateIn()
        }
    }

    @MainActor
    private func displayThomasLayout(
        _ layout: AirshipLayout,
        scene: UIWindowScene,
        analytics: InAppMessageAnalyticsProtocol
    ) async throws -> DisplayResult {
        return try await withCheckedThrowingContinuation { continuation in
            let listener = ThomasDisplayListener(analytics: analytics) { result in
                continuation.resume(returning: result)
            }

            let extensions = ThomasExtensions(
                nativeBridgeExtension: InAppMessageNativeBridgeExtension(
                    message: message
                ),
                imageProvider: AssetCacheImageProvider(assets: assets),
                actionRunner: actionRunner
            )

            do {
                try Thomas.display(
                    layout: layout,
                    scene: scene,
                    extensions: extensions,
                    delegate: listener,
                    extras: message.extras,
                    priority: priority
                )
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

fileprivate class AssetCacheImageProvider : AirshipImageProvider {
    let assets: AirshipCachedAssetsProtocol
    init(assets: AirshipCachedAssetsProtocol) {
        self.assets = assets
    }

    func get(url: URL) -> AirshipImageData? {
        guard 
            let url = assets.cachedURL(remoteURL: url),
            let data = FileManager.default.contents(atPath: url.path),
            let imageData = try? AirshipImageData(data: data)
        else {
            return nil
        }

        return imageData
    }
}
