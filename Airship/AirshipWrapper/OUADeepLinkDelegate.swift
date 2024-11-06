/* Copyright Airship and Contributors */

import Foundation
public import AirshipCore

@objc
public protocol UADeepLinkDelegate {
    
    /// Called when a deep link has been triggered from Airship. If implemented, the delegate is responsible for processing the provided url.
    /// - Parameters:
    ///     - deepLink: The deep link.
    @MainActor
    func receivedDeepLink(_ deepLink: URL) async
    
}

public class UADeepLinkDelegateWrapper: NSObject, DeepLinkDelegate {
    
    private let delegate: UADeepLinkDelegate
    
    init(delegate: UADeepLinkDelegate) {
        self.delegate = delegate
    }
    
    public func receivedDeepLink(_ deepLink: URL) async {
        await self.delegate.receivedDeepLink(deepLink)
    }
    
}
