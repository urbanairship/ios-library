/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import UIKit

/// View controller for Message Center view
@objc(UAMessageCenterViewController)
public class MessageCenterViewControllerFactory: NSObject {

    /// Makes a message view controller with the given theme.
    /// - Parameters:
    ///     - theme: The message center theme.
    ///     - controller: The Message Center controller
    ///     - dismissAction: Optional action to dismiss the view controller.
    /// - Returns: A view controller.
    @objc
    @MainActor
    public class func make(
        theme: MessageCenterTheme? = nil,
        controller: MessageCenterController,
        dismissAction: (() -> Void)? = nil
    ) -> UIViewController {
        let theme = theme ?? MessageCenterTheme()
        return MessageCenterViewController(
            rootView: MessageCenterView(
                controller: controller
            )
            .messageCenterTheme(theme)
            .addMessageCenterDismissAction(
                action: dismissAction
            )
        )
    }
}

private class MessageCenterViewController<Content>: UIHostingController<Content>
where Content: View {

    override init(rootView: Content) {
        super.init(rootView: rootView)
        self.view.backgroundColor = .clear
    }

    @objc
    required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
