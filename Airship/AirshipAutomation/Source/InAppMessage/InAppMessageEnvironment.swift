/* Copyright Airship and Contributors */

import Combine
import Foundation
import UIKit
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

class InAppMessageEnvironment: ObservableObject {
    private let delegate: InAppMessageViewDelegate
    var theme: Theme

    @Published var imageLoader: AirshipImageLoader?
    let nativeBridgeExtension: NativeBridgeExtensionDelegate?

    @Published var isDismissed = false

    @MainActor
    init(
        delegate: InAppMessageViewDelegate,
        theme: Theme,
        extensions: InAppMessageExtensions? = nil
    ) {
        self.delegate = delegate
        self.theme = theme

        self.imageLoader = if let provider = extensions?.imageProvider {
            AirshipImageLoader(imageProvider: provider)
        } else {
            nil
        }

        self.nativeBridgeExtension = extensions?.nativeBridgeExtension
    }

    private func tryDismiss(callback: @escaping () -> Void) {
        if !self.isDismissed {
            withAnimation {
                self.isDismissed = true
            }
            callback()
        }
    }

    @MainActor
    func onAppear() {
        self.delegate.onAppear()
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
