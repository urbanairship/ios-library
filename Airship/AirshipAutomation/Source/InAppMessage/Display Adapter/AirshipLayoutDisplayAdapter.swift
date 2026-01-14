/* Copyright Airship and Contributors */

import Foundation
import UIKit
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

final class AirshipLayoutDisplayAdapter: DisplayAdapter {

    private let message: InAppMessage
    private let priority: Int
    private let assets: any AirshipCachedAssetsProtocol
    private let actionRunner: (any InternalInAppActionRunner)?
    private let networkChecker: any AirshipNetworkCheckerProtocol

    @MainActor
    var themeManager: InAppAutomationThemeManager {
        return Airship.inAppAutomation.inAppMessaging.themeManager
    }

    init(
        message: InAppMessage,
        priority: Int,
        assets: any AirshipCachedAssetsProtocol,
        actionRunner: (any InternalInAppActionRunner)? = nil,
        networkChecker: any AirshipNetworkCheckerProtocol = AirshipNetworkChecker.shared
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
        displayTarget: AirshipDisplayTarget,
        analytics: any InAppMessageAnalyticsProtocol
    ) async throws -> DisplayResult {
        switch (message.displayContent) {
        case .banner(let banner):
            return try await displayBanner(
                banner,
                displayTarget: displayTarget,
                analytics: analytics
            )
        case .modal(let modal):
            return try await displayModal(
                modal,
                displayTarget: displayTarget,
                analytics: analytics
            )
        case .fullscreen(let fullscreen):
            return try await displayFullscreen(
                fullscreen,
                displayTarget: displayTarget,
                analytics: analytics
            )
        case .html(let html):
            return try await displayHTML(
                html,
                displayTarget: displayTarget,
                analytics: analytics
            )
        case .airshipLayout(let layout):
            return try await displayThomasLayout(
                layout,
                displayTarget: displayTarget,
                analytics: analytics
            )
        case .custom(_):
            // This should never happen - constructor will throw
            return .finished
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


    private func makeInAppExtensions() -> InAppMessageExtensions {
#if !os(tvOS)
        InAppMessageExtensions(
            nativeBridgeExtension: InAppMessageNativeBridgeExtension(
                message: message
            ),
            imageProvider: AssetCacheImageProvider(assets: assets),
            actionRunner: actionRunner
        )
#else
        InAppMessageExtensions(
            imageProvider: AssetCacheImageProvider(assets: assets),
            actionRunner: actionRunner
        )
#endif
    }

    @MainActor
    private func displayBanner(
        _ banner: InAppMessageDisplayContent.Banner,
        displayTarget: AirshipDisplayTarget,
        analytics: any InAppMessageAnalyticsProtocol
    ) async throws -> DisplayResult {
        return try await withCheckedThrowingContinuation { continuation in
            let displayable = displayTarget.prepareDisplay(for: .banner)

            let dismissViewController = {
                displayable.dismiss()
            }

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

            do {
                try displayable.display { windowInfo in
                    let bannerConstraints = InAppMessageBannerConstraints(
                        size: windowInfo.size
                    )

                    let rootView = InAppMessageBannerView(
                        environment: environment,
                        displayContent: banner,
                        bannerConstraints: bannerConstraints,
                        theme: theme,
                        onDismiss: dismissViewController
                    )

                    return InAppMessageBannerViewController(
                        rootView: rootView,
                        placement: banner.placement,
                        bannerConstraints: bannerConstraints
                    )
                }
            } catch {
                continuation.resume(
                    throwing: AirshipErrors.error("Failed to find window to display in-app banner \(error)")
                )
            }
        }
    }

    @MainActor
    private func displayModal(
        _ modal: InAppMessageDisplayContent.Modal,
        displayTarget: AirshipDisplayTarget,
        analytics: any InAppMessageAnalyticsProtocol
    ) async throws -> DisplayResult {
        return try await withCheckedThrowingContinuation { continuation in
            let displayable = displayTarget.prepareDisplay(for: .modal)

            let listener = InAppMessageDisplayListener(
                analytics: analytics
            ) { result in
                displayable.dismiss()
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

            do {
                try displayable.display { _ in
                    let viewController = InAppMessageHostingController(rootView: rootView)
                    viewController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
                    return viewController
                }
            } catch {
                continuation.resume(
                    throwing: AirshipErrors.error("Failed to find window to display in-app banner \(error)")
                )
            }
        }
    }

    @MainActor
    private func displayFullscreen(
        _ fullscreen: InAppMessageDisplayContent.Fullscreen,
        displayTarget: AirshipDisplayTarget,
        analytics: any InAppMessageAnalyticsProtocol
    ) async throws -> DisplayResult {
        return try await withCheckedThrowingContinuation { continuation in
            let displayable = displayTarget.prepareDisplay(for: .modal)

            let listener = InAppMessageDisplayListener(
                analytics: analytics
            ) { result in
                displayable.dismiss()
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

            do {
                try displayable.display { _ in
                    let viewController = InAppMessageHostingController(rootView: rootView)
                    viewController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
                    return viewController
                }
            } catch {
                continuation.resume(
                    throwing: AirshipErrors.error("Failed to find window to display in-app banner \(error)")
                )
            }
        }
    }

    @MainActor
    private func displayHTML(
        _ html: InAppMessageDisplayContent.HTML,
        displayTarget: AirshipDisplayTarget,
        analytics: any InAppMessageAnalyticsProtocol
    ) async throws -> DisplayResult {
#if !os(tvOS)
        return try await withCheckedThrowingContinuation { continuation in
            let displayable = displayTarget.prepareDisplay(for: .modal)

            let listener = InAppMessageDisplayListener(
                analytics: analytics
            ) { result in
                displayable.dismiss()
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

            do {
                try displayable.display { _ in
                    let viewController = InAppMessageHostingController(rootView: rootView)
                    viewController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
                    return viewController
                }
            } catch {
                continuation.resume(
                    throwing: AirshipErrors.error("Failed to find window to display in-app banner \(error)")
                )
            }
        }
#else
        return .cancel
#endif
    }

    @MainActor
    private func displayThomasLayout(
        _ layout: AirshipLayout,
        displayTarget: AirshipDisplayTarget,
        analytics: any InAppMessageAnalyticsProtocol
    ) async throws -> DisplayResult {
        return try await withCheckedThrowingContinuation { continuation in
            let listener = ThomasDisplayListener(analytics: analytics) { result in
                continuation.resume(returning: result.automationDisplayResult)
            }

#if !os(tvOS)
            let extensions = ThomasExtensions(
                nativeBridgeExtension: InAppMessageNativeBridgeExtension(
                    message: message
                ),
                imageProvider: AssetCacheImageProvider(assets: assets),
                actionRunner: actionRunner
            )

#else
            let extensions = ThomasExtensions(
                imageProvider: AssetCacheImageProvider(assets: assets),
                actionRunner: actionRunner
            )
#endif
            do {
                try Thomas.display(
                    layout: layout,
                    displayTarget: displayTarget,
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
    let assets: any AirshipCachedAssetsProtocol
    init(assets: any AirshipCachedAssetsProtocol) {
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

extension ThomasDisplayListener.DisplayResult {
    var automationDisplayResult: DisplayResult {
        return switch self {
            case .finished: .finished
            case .cancel: .cancel
            @unknown default: .finished
        }
    }
}
