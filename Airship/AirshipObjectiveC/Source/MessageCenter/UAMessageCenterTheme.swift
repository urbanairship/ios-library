/* Copyright Airship and Contributors */

public import Foundation
public import UIKit

#if canImport(AirshipCore)
import AirshipMessageCenter
import AirshipCore
#endif

/// Message Center theme
@objc
public final class UAMessageCenterTheme: NSObject {
    
    @objc
    /// The tint color of the "pull to refresh" control
    public var refreshTintColor: UIColor? = nil

    @objc
    /// The dark mode tint color of the "pull to refresh" control
    public var refreshTintColorDark: UIColor? = nil

    @objc
    /// Whether icons are enabled. Defaults to `NO`.
    public var iconsEnabled: Bool = false

    @objc
    /// An optional placeholder image to use when icons haven't fully loaded.
    public var placeholderIcon: UIImage? = nil

    @objc
    /// The font to use for message cell titles.
    public var cellTitleFont: UIFont? = UIFont.preferredFont(forTextStyle: .headline)

    @objc
    /// The font to use for message cell dates.
    public var cellDateFont: UIFont? = UIFont.preferredFont(forTextStyle: .subheadline)

    @objc
    /// The regular color for message cells
    public var cellColor: UIColor? = nil

    @objc
    /// The dark mode color for message cells
    public var cellColorDark: UIColor? = nil

    @objc
    /// The regular color for message cell titles.
    public var cellTitleColor: UIColor? = .label

    @objc
    /// The dark mode color for message cell titles.
    public var cellTitleColorDark: UIColor? = nil

    @objc
    /// The regular color for message cell dates.
    public var cellDateColor: UIColor? = .secondaryLabel

    @objc
    /// The dark mode color for message cell dates.
    public var cellDateColorDark: UIColor? = nil

    @objc
    /// The message cell tint color.
    public var cellTintColor: UIColor? = nil

    @objc
    /// The dark mode message cell tint color.
    public var cellTintColorDark: UIColor? = nil

    @objc
    /// The background color for the unread indicator.
    public var unreadIndicatorColor: UIColor? = nil

    @objc
    /// The dark mode background color for the unread indicator.
    public var unreadIndicatorColorDark: UIColor? = nil

    @objc
    /// The title color for the "Select All" button.
    public var selectAllButtonTitleColor: UIColor? = nil

    @objc
    /// The dark mode title color for the "Select All" button.
    public var selectAllButtonTitleColorDark: UIColor? = nil

    @objc
    /// The title color for the "Delete" button.
    public var deleteButtonTitleColor: UIColor? = nil

    @objc
    /// The dark mode title color for the "Delete" button.
    public var deleteButtonTitleColorDark: UIColor? = nil

    @objc
    /// The title color for the "Mark Read" button.
    public var markAsReadButtonTitleColor: UIColor? = nil

    @objc
    /// The dark mode title color for the "Mark Read" button.
    public var markAsReadButtonTitleColorDark: UIColor? = nil

    @objc
    /// Whether the delete message button from the message view is enabled. Defaults to `NO`.
    public var hideDeleteButton: Bool = false

    @objc
    /// The title color for the "Edit" button.
    public var editButtonTitleColor: UIColor? = nil

    @objc
    /// The dark mode title color for the "Edit" button.
    public var editButtonTitleColorDark: UIColor? = nil

    @objc
    /// The title color for the "Cancel" button.
    public var cancelButtonTitleColor: UIColor? = nil

    @objc
    /// The dark mode title color for the "Cancel" button.
    public var cancelButtonTitleColorDark: UIColor? = nil

    @objc
    /// The title color for the "Done" button.
    public var backButtonColor: UIColor? = nil

    @objc
    /// The dark mode title color for the "Done" button.
    public var backButtonColorDark: UIColor? = nil

    @objc
    /// The navigation bar title
    public var navigationBarTitle: String? = nil

    @objc
    /// The background of the message list.
    public var messageListBackgroundColor: UIColor? = nil

    @objc
    /// The dark mode background of the message list.
    public var messageListBackgroundColorDark: UIColor? = nil

    @objc
    /// The background of the message list container.
    public var messageListContainerBackgroundColor: UIColor? = nil

    @objc
    /// The dark mode background of the message list container.
    public var messageListContainerBackgroundColorDark: UIColor? = nil

    @objc
    /// The background of the message view.
    public var messageViewBackgroundColor: UIColor? = nil

    @objc
    /// The dark mode background of the message view.
    public var messageViewBackgroundColorDark: UIColor? = nil

    @objc
    /// The background of the message view container.
    public var messageViewContainerBackgroundColor: UIColor? = nil

    @objc
    /// The dark mode background of the message view container.
    public var messageViewContainerBackgroundColorDark: UIColor? = nil

}
    

