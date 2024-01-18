/* Copyright Airship and Contributors */

import Combine
import Foundation
import UIKit

#if canImport(AirshipCore)
import AirshipCore
#endif

class InAppMessageEnvironment: ObservableObject {
    private let delegate: InAppMessageResolutionDelegate
    let imageLoader: AirshipImageLoader

    var theme: Theme

    @Published var isDismissed = false

    var onDismiss: (() -> Void)?

    @MainActor
    init(
        delegate: InAppMessageResolutionDelegate,
        imageLoader: AirshipImageLoader,
        theme:Theme,
        onDismiss: (() -> Void)? = nil
    ) {
        self.delegate = delegate
        self.onDismiss = onDismiss
        self.imageLoader = imageLoader
        self.theme = theme
    }

    private func tryDismiss(callback: () -> Void) {
        if !self.isDismissed {
            self.isDismissed = true
            callback()
            onDismiss?()
            onDismiss = nil
        }
    }

    /// Called when a button dismisses the in-app message
    /// - Parameters:
    ///     - buttonInfo: The button info on the dismissing button.
    func onButtonDismissed(buttonInfo: InAppMessageButtonInfo) {
        tryDismiss {
            self.delegate.onButtonDismissed(buttonInfo: buttonInfo)
        }
    }

    /// Called when a message dismisses after the set timeout period
    func onTimedOut() {
        tryDismiss {
            self.delegate.onTimedOut()
        }
    }

    /// Called when a message dismisses with the close button or banner drawer handle
    func onUserDismissed() {
        tryDismiss {
            self.delegate.onUserDismissed()
        }
    }

    /// Called when a message is dismissed via a tap to the message body
    func onMessageTapDismissed() {
        tryDismiss {
            self.delegate.onMessageTapDismissed()
        }
    }
}
