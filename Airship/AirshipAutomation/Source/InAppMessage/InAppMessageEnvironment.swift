/* Copyright Airship and Contributors */

import Combine
import Foundation
import UIKit
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

class InAppMessageEnvironment: ObservableObject {
    private let delegate: InAppMessageResolutionDelegate
    var theme: Theme

    @Published var imageLoader: AirshipImageLoader?
    let nativeBridgeExtension: NativeBridgeExtensionDelegate?

    @Published var isDismissed = false

    var onDismiss: (() -> Void)?

    @MainActor
    init(
        delegate: InAppMessageResolutionDelegate,
        theme: Theme,
        extensions: InAppMessageExtensions? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.delegate = delegate
        self.theme = theme

        self.imageLoader = if let provider = extensions?.imageProvider {
            AirshipImageLoader(imageProvider: provider)
        } else {
            nil
        }

        self.nativeBridgeExtension = extensions?.nativeBridgeExtension

        self.onDismiss = onDismiss
    }

    private func tryDismiss(callback:@escaping () -> Void) {
        if !self.isDismissed {
            withAnimation {
                self.isDismissed = true
            }

            self.onDismiss?()
            self.onDismiss = nil
            callback()
        }
    }

    /// Called when a button dismisses the in-app message
    /// - Parameters:
    ///     - buttonInfo: The button info on the dismissing button.
    @MainActor
    func onButtonDismissed(buttonInfo: InAppMessageButtonInfo) {
        tryDismiss {
            self.delegate.onButtonDismissed(buttonInfo: buttonInfo)
        }
    }

    /// Called when a message dismisses after the set timeout period
    @MainActor
    func onTimedOut() {
        tryDismiss {
            self.delegate.onTimedOut()
        }
    }

    /// Called when a message dismisses with the close button or banner drawer handle
    @MainActor
    func onUserDismissed() {
        tryDismiss {
           self.delegate.onUserDismissed()
        }
    }

    /// Called when a message is dismissed via a tap to the message body
    @MainActor
    func onMessageTapDismissed() {
        tryDismiss {
            self.delegate.onMessageTapDismissed()
        }
    }
}
