/* Copyright Airship and Contributors */

import Foundation
import UIKit

#if canImport(AirshipCore)
import AirshipCore
#endif

final class AirshipLayoutDisplayAdapter: DisplayAdapter {

    private let message: InAppMessage
    private let assets: AirshipCachedAssetsProtocol
    private let networkChecker: NetworkCheckerProtocol

    init(
        message: InAppMessage,
        assets: AirshipCachedAssetsProtocol,
        networkChecker: NetworkCheckerProtocol = NetworkChecker()
    ) throws {
        self.message = message
        self.assets = assets
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

    @MainActor
    private func displayBanner(
        _ banner: InAppMessageDisplayContent.Banner,
        scene: UIWindowScene,
        analytics: InAppMessageAnalyticsProtocol
    ) async throws -> DisplayResult {
        return try await withCheckedThrowingContinuation { continuation in
    
            guard let window = AirshipUtils.mainWindow(scene: scene),
                  window.rootViewController != nil
            else {
                continuation.resume(
                    throwing: AirshipErrors.error("Failed to find window to display in-app banner")
                )
                return
            }
            
            var viewController: InAppMessageBannerViewController?
            let dismissViewController = {
                viewController?.view.removeFromSuperview()
                viewController = nil
            }
            
            let listener = InAppMessageDisplayListener(
                analytics: analytics
            ) { result in
                // Dismiss the In app message banner view controller
                continuation.resume(returning: result)
            }

            let environment = InAppMessageEnvironment(
                delegate: listener,
                theme: Theme.banner(BannerTheme()),
                extensions: InAppMessageExtensions(imageProvider: AssetCacheImageProvider(assets: assets))
            )

            let bannerConstraints = InAppMessageBannerConstraints(
                size: Self.windowSize(window)
            )

            let rootView = InAppMessageBannerView(environment: environment, 
                                                  displayContent: banner,
                                                  bannerConstraints: bannerConstraints,
                                                  onDismiss: dismissViewController)

            viewController = InAppMessageBannerViewController(
                rootView: rootView,
                placement: banner.placement,
                bannerConstraints: bannerConstraints
            )

            window.addRootController(viewController)
        }
    }

    @MainActor
    private func displayModal(
        _ modal: InAppMessageDisplayContent.Modal,
        scene: UIWindowScene,
        analytics: InAppMessageAnalyticsProtocol
    ) async -> DisplayResult {
        return await withCheckedContinuation { continuation in
            let window = UIWindow.makeModalReadyWindow(scene: scene)

            let listener = InAppMessageDisplayListener(
                analytics: analytics
            ) { result in
                window.animateOut()
                continuation.resume(returning: result)
            }

            let environment = InAppMessageEnvironment(
                delegate: listener,
                theme: Theme.modal(ModalTheme()),
                extensions: InAppMessageExtensions(imageProvider: AssetCacheImageProvider(assets: assets))
            )

            let rootView = InAppMessageRootView(inAppMessageEnvironment: environment) { orientation in
                InAppMessageModalView(displayContent: modal)
            }

            let viewController = InAppMessageHostingController(rootView: rootView)
            viewController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
            window.rootViewController = viewController

            window.animateIn()
        }
    }

    @MainActor
    private func displayFullscreen(
        _ fullscreen: InAppMessageDisplayContent.Fullscreen,
        scene: UIWindowScene,
        analytics: InAppMessageAnalyticsProtocol
    ) async -> DisplayResult {
        return await withCheckedContinuation { continuation in
            let window = UIWindow.makeModalReadyWindow(scene: scene)

            let listener = InAppMessageDisplayListener(
                analytics: analytics
            ) { result in
                window.animateOut()
                continuation.resume(returning: result)
            }

            let environment = InAppMessageEnvironment(
                delegate: listener,
                theme: Theme.fullScreen(FullScreenTheme()),
                extensions: InAppMessageExtensions(imageProvider: AssetCacheImageProvider(assets: assets))
            )

            let rootView = InAppMessageRootView(inAppMessageEnvironment: environment) { orientation in
                FullScreenView(displayContent: fullscreen)
            }

            let viewController = InAppMessageHostingController(rootView: rootView)
            viewController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
            window.rootViewController = viewController

            window.animateIn()
        }
    }

    @MainActor
    private func displayHTML(
        _ html: InAppMessageDisplayContent.HTML,
        scene: UIWindowScene,
        analytics: InAppMessageAnalyticsProtocol
    ) async -> DisplayResult {
        return await withCheckedContinuation { continuation in
            let window = UIWindow.makeModalReadyWindow(scene: scene)

            let listener = InAppMessageDisplayListener(
                analytics: analytics
            ) { result in
                window.animateOut()
                continuation.resume(returning: result)
            }

            let environment = InAppMessageEnvironment(
                delegate: listener,
                theme: Theme.html(HTMLTheme()),
                extensions: InAppMessageExtensions(nativeBridgeExtension: InAppMessageNativeBridgeExtension(
                    message: message
                ), imageProvider: AssetCacheImageProvider(assets: assets))
            )

            let rootView = InAppMessageRootView(inAppMessageEnvironment: environment) { orientation in
                HTMLView(displayContent: html)
            }

            let viewController = InAppMessageHostingController(rootView: rootView)
            viewController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
            window.rootViewController = viewController

            window.animateIn()
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
                imageProvider: AssetCacheImageProvider(assets: assets)
            )

            do {
                try Thomas.display(
                    layout: layout,
                    scene: scene,
                    extensions: extensions,
                    delegate: listener
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

private extension UIWindow {

    static func makeModalReadyWindow(
        scene: UIWindowScene
    ) -> UIWindow {
        let window: UIWindow = UIWindow(windowScene: scene)
        window.accessibilityViewIsModal = false
        window.alpha = 0
        window.makeKeyAndVisible()
        window.isUserInteractionEnabled = false
        
        return window
    }
    
    func addRootController<T: UIViewController>(
        _ viewController: T?
    ) {
        viewController?.modalPresentationStyle = UIModalPresentationStyle.automatic
        viewController?.view.isUserInteractionEnabled = true
        
        if let viewController = viewController,
           let rootController = self.rootViewController
        {
            rootController.addChild(viewController)
            viewController.didMove(toParent: rootController)
            rootController.view.addSubview(viewController.view)
        }
        
        self.isUserInteractionEnabled = true
    }
    
    func animateIn() {
        self.makeKeyAndVisible()
        self.isUserInteractionEnabled = true

        UIView.animate(
            withDuration: 0.3,
            animations: {
                self.alpha = 1
            },
            completion: { _ in
            }
        )
    }

    func animateOut() {
        UIView.animate(
            withDuration: 0.3,
            animations: {
                self.alpha = 0
            },
            completion: { _ in
                self.isHidden = true
                self.isUserInteractionEnabled = false
                self.removeFromSuperview()
            }
        )
    }
}
