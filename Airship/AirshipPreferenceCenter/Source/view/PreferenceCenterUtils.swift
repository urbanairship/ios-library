/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

internal extension View {
    @ViewBuilder
    func backgroundWithCloseAction(onClose: (()->())?) -> some View {
        ZStack {
            Rectangle()
                .foregroundColor(Color.clear)
                .background(Color.airshipTappableClear.ignoresSafeArea(.all))
                .onTapGesture {
                    if let onClose = onClose {
                        onClose()
                    }
                }
                .zIndex(0)
            self.zIndex(1)
        }
    }
}

#if !os(macOS)
internal extension UIWindow {
    static func makeModalReadyWindow(scene: UIWindowScene) -> UIWindow {
        let window = AirshipWindowFactory.shared.makeWindow(windowScene: scene)
        window.accessibilityViewIsModal = false
        window.alpha = 0
        window.makeKeyAndVisible()
        window.isUserInteractionEnabled = false
        return window
    }

    func animateIn() {
        self.windowLevel = .alert
        self.makeKeyAndVisible()
        self.isUserInteractionEnabled = true

        UIView.animate(withDuration: 0.3) {
            self.alpha = 1
        }
    }

    func animateOut() {
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
        }, completion: { _ in
            self.isHidden = true
            self.isUserInteractionEnabled = false
            self.removeFromSuperview()
        })
    }
}
#else
internal extension NSWindow {
    static func makeModalReadyWindow() -> NSWindow {
        let window = AirshipWindowFactory.shared.makeWindow()

        // On macOS, modal accessibility is usually handled at the view level
        window.contentView?.setAccessibilityModal(false)
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        window.ignoresMouseEvents = true

        return window
    }

    func animateIn() {
        self.level = .modalPanel // Equivalent to .alert level on iOS
        self.makeKeyAndOrderFront(nil)
        self.ignoresMouseEvents = false

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            self.animator().alphaValue = 1
        }
    }

    func animateOut() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            self.animator().alphaValue = 0
        }, completionHandler: {
            // Ensure we are on MainActor for UI changes
            Task { @MainActor in
                self.orderOut(nil)
                self.ignoresMouseEvents = true
            }
        })
    }
}
#endif
