/* Copyright Airship and Contributors */


import SwiftUI
import UIKit

/// View controller for Message Center view
public class MessageCenterViewControllerFactory: NSObject {

    /// Makes a message view controller with the given theme.
    /// - Parameters:
    ///     - theme: The message center theme.
    ///     - predicate: The message center predicate.
    ///     - controller: The Message Center controller
    ///     - dismissAction: Optional action to dismiss the view controller.
    /// - Returns: A view controller.
    @MainActor
    public class func make(
        theme: MessageCenterTheme? = nil,
        predicate: (any MessageCenterPredicate)? = nil,
        controller: MessageCenterController,
        dismissAction: (@MainActor @Sendable () -> Void)? = nil
    ) -> UIViewController {
        let theme = theme ?? MessageCenterTheme()
        return MessageCenterViewController(
            rootView: MessageCenterView(
                controller: controller
            )
            .messageCenterTheme(theme)
            .messageCenterPredicate(predicate)
            .addMessageCenterDismissAction(
                action: dismissAction
            )
        )
    }

    /// Makes a message view controller with the given theme.
    /// - Parameters:
    ///     - themePlist: A path to a theme plist
    ///     - controller: The Message Center controller
    ///     - dismissAction: Optional action to dismiss the view controller.
    /// - Returns: A view controller.
    @MainActor
    public class func make(
        themePlist: String?,
        controller: MessageCenterController,
        dismissAction: (@Sendable () -> Void)? = nil
    ) throws -> UIViewController {
        
        if let themePlist = themePlist {
            return make(
                theme: try MessageCenterThemeLoader.fromPlist(themePlist),
                controller: controller,
                dismissAction: dismissAction
            )
        } else {
            return make(
                controller: controller,
                dismissAction: dismissAction
            )
        }
    }
    
    /// Makes a message view controller with the given theme.
    /// - Parameters:
    ///     - themePlist: A path to a theme plist
    ///     - predicate: The message center predicate
    ///     - controller: The Message Center controller
    ///     - dismissAction: Optional action to dismiss the view controller.
    /// - Returns: A view controller.
    @MainActor
    public class func make(
        themePlist: String?,
        predicate: (any MessageCenterPredicate)?,
        controller: MessageCenterController,
        dismissAction: (@Sendable () -> Void)? = nil
    ) throws -> UIViewController {

        if let themePlist = themePlist {
            return make(
                theme: try MessageCenterThemeLoader.fromPlist(themePlist),
                predicate: predicate,
                controller: controller,
                dismissAction: dismissAction
            )
        } else {
            return make(
                predicate: predicate,
                controller: controller,
                dismissAction: dismissAction
            )
        }
    }
}

private class MessageCenterViewController<Content>: UIHostingController<Content>
where Content: View {

    override init(rootView: Content) {
        super.init(rootView: rootView)
        self.view.backgroundColor = .clear
    }

    required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
