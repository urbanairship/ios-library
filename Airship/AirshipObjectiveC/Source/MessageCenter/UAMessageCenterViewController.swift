/* Copyright Airship and Contributors */

public import Foundation
public import UIKit

#if canImport(AirshipCore)
import AirshipMessageCenter
import AirshipCore
import SwiftUICore
#endif

/// Message Center view controller factory
@objc
public final class UAMessageCenterViewControllerFactory: NSObject, Sendable {
    
    @objc
    /// Makes a message view controller with the given theme.
    /// - Parameters:
    ///     - theme: The message center theme.
    ///     - predicate: The message center predicate.
    /// - Returns: A view controller.
    @MainActor
    public class func make(
        theme: UAMessageCenterTheme? = nil,
        predicate: (any UAMessageCenterPredicate)? = nil
    ) -> UIViewController {
        var airshipTheme: MessageCenterTheme?
        var wrapper: UAMessageCenterPredicateWrapper?
        
        if let theme = theme {
            airshipTheme = UAMessageCenterViewControllerFactory.toAirshipTheme(theme: theme)
        }
        if let predicate = predicate {
            wrapper = UAMessageCenterPredicateWrapper(delegate: predicate)
        }
        return MessageCenterViewControllerFactory.make(theme: airshipTheme, predicate: wrapper, controller: MessageCenterController())
    }
    

    @objc
    /// Makes a message view controller with the given theme.
    /// - Parameters:
    ///     - themePlist: A path to a theme plist
    /// - Returns: A view controller.
    @MainActor
    public class func make(
        themePlist: String?
    ) throws -> UIViewController {
        return try MessageCenterViewControllerFactory.make(themePlist: themePlist, controller: MessageCenterController())
    }
    
    @objc
    /// Makes a message view controller with the given theme.
    /// - Parameters:
    ///     - themePlist: A path to a theme plist
    ///     - predicate: The message center predicate
    /// - Returns: A view controller.
    @MainActor
    public class func make(
        themePlist: String?,
        predicate: (any UAMessageCenterPredicate)?
    ) throws -> UIViewController {
        if let predicate = predicate {
            let wrapper = UAMessageCenterPredicateWrapper(delegate: predicate)
            return try MessageCenterViewControllerFactory.make(themePlist: themePlist, predicate: wrapper, controller: MessageCenterController())
        }
        return try MessageCenterViewControllerFactory.make(themePlist: themePlist, controller: MessageCenterController())
    }

    @objc
    /// Embeds the message center view in another view.
    /// - Parameters:
    ///   - theme: The message center theme.
    ///   - predicate: The message center predicate.
    ///   - parentViewController: The parent view controller into which we'll embed the message center.
    /// - Returns: A UIView to be added into another view.
    @MainActor
    public class func embed(
        theme: UAMessageCenterTheme? = nil,
        predicate: (any UAMessageCenterPredicate)? = nil,
        in parentViewController: UIViewController
    ) -> UIView {
        let childVC = self.make(theme: theme, predicate: predicate)
        parentViewController.addChild(childVC)

        let containerView = UIView(frame: .zero)
        containerView.addSubview(childVC.view)
        childVC.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            childVC.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            childVC.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            childVC.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            childVC.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        childVC.didMove(toParent: parentViewController)
        return containerView
    }

    private class func toAirshipTheme(theme: UAMessageCenterTheme) -> MessageCenterTheme {
        return MessageCenterTheme(
            refreshTintColor: UAMessageCenterViewControllerFactory.toColor(color: theme.refreshTintColor),
            refreshTintColorDark: UAMessageCenterViewControllerFactory.toColor(color: theme.refreshTintColorDark),
            iconsEnabled: theme.iconsEnabled,
            placeholderIcon: UAMessageCenterViewControllerFactory.toImage(image: theme.placeholderIcon),
            cellTitleFont: UAMessageCenterViewControllerFactory.toFont(font: theme.cellTitleFont),
            cellDateFont: UAMessageCenterViewControllerFactory.toFont(font: theme.cellDateFont),
            cellColor: UAMessageCenterViewControllerFactory.toColor(color: theme.cellColor),
            cellColorDark: UAMessageCenterViewControllerFactory.toColor(color: theme.cellColorDark),
            cellTitleColor: UAMessageCenterViewControllerFactory.toColor(color: theme.cellTitleColor),
            cellTitleColorDark: UAMessageCenterViewControllerFactory.toColor(color: theme.cellTitleColorDark),
            cellDateColor: UAMessageCenterViewControllerFactory.toColor(color: theme.cellDateColor),
            cellDateColorDark: UAMessageCenterViewControllerFactory.toColor(color: theme.cellDateColorDark),
            cellSeparatorStyle: nil,
            cellSeparatorColor: nil,
            cellSeparatorColorDark: nil,
            cellTintColor: UAMessageCenterViewControllerFactory.toColor(color: theme.cellTintColor),
            cellTintColorDark: UAMessageCenterViewControllerFactory.toColor(color: theme.cellTintColorDark),
            unreadIndicatorColor: UAMessageCenterViewControllerFactory.toColor(color: theme.unreadIndicatorColor),
            unreadIndicatorColorDark: UAMessageCenterViewControllerFactory.toColor(color: theme.unreadIndicatorColorDark),
            selectAllButtonTitleColor: UAMessageCenterViewControllerFactory.toColor(color: theme.selectAllButtonTitleColor),
            selectAllButtonTitleColorDark: UAMessageCenterViewControllerFactory.toColor(color: theme.selectAllButtonTitleColorDark),
            deleteButtonTitleColor: UAMessageCenterViewControllerFactory.toColor(color: theme.deleteButtonTitleColor),
            deleteButtonTitleColorDark: UAMessageCenterViewControllerFactory.toColor(color: theme.deleteButtonTitleColorDark),
            markAsReadButtonTitleColor: UAMessageCenterViewControllerFactory.toColor(color: theme.markAsReadButtonTitleColor),
            markAsReadButtonTitleColorDark: UAMessageCenterViewControllerFactory.toColor(color: theme.markAsReadButtonTitleColorDark),
            hideDeleteButton: theme.hideDeleteButton,
            editButtonTitleColor: UAMessageCenterViewControllerFactory.toColor(color: theme.editButtonTitleColor),
            editButtonTitleColorDark: UAMessageCenterViewControllerFactory.toColor(color: theme.editButtonTitleColorDark),
            cancelButtonTitleColor: UAMessageCenterViewControllerFactory.toColor(color: theme.cancelButtonTitleColor),
            cancelButtonTitleColorDark: UAMessageCenterViewControllerFactory.toColor(color: theme.cancelButtonTitleColorDark),
            backButtonColor: UAMessageCenterViewControllerFactory.toColor(color: theme.backButtonColor),
            backButtonColorDark: UAMessageCenterViewControllerFactory.toColor(color: theme.backButtonColorDark),
            navigationBarTitle: theme.navigationBarTitle, messageListBackgroundColor: UAMessageCenterViewControllerFactory.toColor(color: theme.messageListBackgroundColor),
            messageListBackgroundColorDark: UAMessageCenterViewControllerFactory.toColor(color: theme.messageListBackgroundColorDark),
            messageListContainerBackgroundColor: UAMessageCenterViewControllerFactory.toColor(color: theme.messageListContainerBackgroundColor),
            messageListContainerBackgroundColorDark: UAMessageCenterViewControllerFactory.toColor(color: theme.messageListContainerBackgroundColorDark),
            messageViewBackgroundColor: UAMessageCenterViewControllerFactory.toColor(color: theme.messageViewBackgroundColor),
            messageViewBackgroundColorDark: UAMessageCenterViewControllerFactory.toColor(color: theme.messageViewBackgroundColorDark),
            messageViewContainerBackgroundColor: UAMessageCenterViewControllerFactory.toColor(color: theme.messageViewContainerBackgroundColor),
            messageViewContainerBackgroundColorDark: UAMessageCenterViewControllerFactory.toColor(color: theme.messageViewContainerBackgroundColorDark))
    }
    
    private class func toColor(color: UIColor?) -> Color? {
        if let color = color {
            return Color(color)
        }
        return nil
    }
    
    private class func toFont(font: UIFont?) -> Font? {
        if let font = font {
            return Font(font)
        }
        return nil
    }
    
    private class func toImage(image: UIImage?) -> Image? {
        if let image = image {
            return Image(uiImage: image)
        }
        return nil
    }
}
