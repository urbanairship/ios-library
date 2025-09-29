/* Copyright Airship and Contributors */

import AirshipCore
import AirshipMessageCenter
import AirshipPreferenceCenter
import Foundation

/// Example deep linking and UI routing handler.
///
/// This is a sample implementation showing how to handle deep links and
/// route Airship features to your app's navigation system.
///
/// - Note: This is an example - customize for your app's needs.
struct DeepLinkHandler {

    /// Error types that can occur during deep link processing
    public enum DeepLinkError: Error, LocalizedError {
        case invalidURL(String)
        case unsupportedHost(String)
        case unsupportedPath(String)
        case routerNotAvailable

        public var errorDescription: String? {
            switch self {
            case .invalidURL(let url):
                return "Invalid deep link URL: \(url)"
            case .unsupportedHost(let host):
                return "Unsupported deep link host: \(host)"
            case .unsupportedPath(let path):
                return "Unsupported deep link path: \(path)"
            case .routerNotAvailable:
                return "App router is not available"
            }
        }
    }

    /// Sets up example deep linking and UI routing.
    ///
    /// - Parameters:
    ///   - router: The app router that manages navigation state
    ///   - onError: Optional callback for handling deep link errors
    @MainActor
    static func setup(
        router: AppRouter,
        onError: (@MainActor @Sendable (DeepLinkError) -> Void)? = nil
    ) {
        Airship.onDeepLink = { [weak router] url in
            do {
                try processDeepLink(url: url, router: router, onError: onError)
            } catch let error as DeepLinkError {
                onError?(error)
            } catch {
                onError?(.invalidURL(url.absoluteString))
            }
        }

        // Preference Center routing
        Airship.preferenceCenter.onDisplay = { [weak router] identifier in
            guard identifier == router?.preferenceCenterID else {
                return false
            }
            router?.selectedTab = .preferenceCenter
            return true
        }

        // Message Center routing
        Airship.messageCenter.onDisplay = { [weak router] _ in
            router?.selectedTab = .messageCenter
            return true
        }
    }

    @MainActor
    private static func processDeepLink(
        url: URL,
        router: AppRouter?,
        onError: ((DeepLinkError) -> Void)?
    ) throws {
        guard let router = router else {
            throw DeepLinkError.routerNotAvailable
        }

        guard url.host?.lowercased() == "deeplink" else {
            throw DeepLinkError.unsupportedHost(url.host ?? "nil")
        }

        let components = url.path.lowercased().split(separator: "/")
        guard let firstComponent = components.first else {
            throw DeepLinkError.unsupportedPath(url.path)
        }

        switch firstComponent {
        case "home":
            router.homePath = []
            router.selectedTab = .home
        case "preferences":
            router.selectedTab = .preferenceCenter
        case "message_center":
            router.selectedTab = .messageCenter
        default:
            throw DeepLinkError.unsupportedPath(String(firstComponent))
        }
    }
}
