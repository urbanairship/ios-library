/* Copyright Airship and Contributors */

public import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

@objc
public protocol UADeepLinkDelegate: Sendable {
    
    /// Called when a deep link has been triggered from Airship. If implemented, the delegate is responsible for processing the provided url.
    /// - Parameters:
    ///     - deepLink: The deep link.
    @MainActor
    func receivedDeepLink(_ deepLink: URL) async
}

@MainActor
final class UADeepLinkDelegateWrapper: NSObject, DeepLinkDelegate {
    
    var forwardDelegate: (any UADeepLinkDelegate)?

    init(delegate: any UADeepLinkDelegate) {
        self.forwardDelegate = delegate
    }
    
    public func receivedDeepLink(_ deepLink: URL) async {
        await self.forwardDelegate?.receivedDeepLink(deepLink)
    }
    
}
