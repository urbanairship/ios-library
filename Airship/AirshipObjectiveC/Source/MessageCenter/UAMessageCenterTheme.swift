/* Copyright Airship and Contributors */

public import Foundation
public import UIKit

#if canImport(AirshipCore)
import AirshipMessageCenter
public import AirshipCore
#endif

/// Message Center theme
@objc
public final class UAMessageCenterTheme: NSObject {
    
    @objc
    /// The tint color of the "pull to refresh" control
    public var refreshTintColor: AirshipNativeColor? = nil

    @objc
    /// The dark mode tint color of the "pull to refresh" control
    public var refreshTintColorDark: AirshipNativeColor? = nil

    @objc
    /// Whether icons are enabled. Defaults to `NO`.
    public var iconsEnabled: Bool = false

    @objc
    /// An optional placeholder image to use when icons haven't fully loaded.
    public var placeholderIcon: AirshipNativeImage? = nil

    @objc
    /// The font to use for message cell titles.
    public var cellTitleFont: AirshipNativeFont? = AirshipNativeFont.preferredFont(forTextStyle: .headline)

    @objc
    /// The font to use for message cell dates.
    public var cellDateFont: AirshipNativeFont? = AirshipNativeFont.preferredFont(forTextStyle: .subheadline)

    @objc
    /// The regular color for message cells
    public var cellColor: AirshipNativeColor? = nil

    @objc
    /// The dark mode color for message cells
    public var cellColorDark: AirshipNativeColor? = nil

    @objc
    /// The regular color for message cell titles.
    public var cellTitleColor: AirshipNativeColor? = .label

    @objc
    /// The dark mode color for message cell titles.
    public var cellTitleColorDark: AirshipNativeColor? = nil

    @objc
    /// The regular color for message cell dates.
    public var cellDateColor: AirshipNativeColor? = .secondaryLabel

    @objc
    /// The dark mode color for message cell dates.
    public var cellDateColorDark: AirshipNativeColor? = nil

    @objc
    /// The message cell tint color.
    public var cellTintColor: AirshipNativeColor? = nil

    @objc
    /// The dark mode message cell tint color.
    public var cellTintColorDark: AirshipNativeColor? = nil

    @objc
    /// The background color for the unread indicator.
    public var unreadIndicatorColor: AirshipNativeColor? = nil

    @objc
    /// The dark mode background color for the unread indicator.
    public var unreadIndicatorColorDark: AirshipNativeColor? = nil

    @objc
    /// The title color for the "Select All" button.
    public var selectAllButtonTitleColor: AirshipNativeColor? = nil

    @objc
    /// The dark mode title color for the "Select All" button.
    public var selectAllButtonTitleColorDark: AirshipNativeColor? = nil

    @objc
    /// The title color for the "Delete" button.
    public var deleteButtonTitleColor: AirshipNativeColor? = nil

    @objc
    /// The dark mode title color for the "Delete" button.
    public var deleteButtonTitleColorDark: AirshipNativeColor? = nil

    @objc
    /// The title color for the "Mark Read" button.
    public var markAsReadButtonTitleColor: AirshipNativeColor? = nil

    @objc
    /// The dark mode title color for the "Mark Read" button.
    public var markAsReadButtonTitleColorDark: AirshipNativeColor? = nil

    @objc
    /// Whether the delete message button from the message view is enabled. Defaults to `NO`.
    public var hideDeleteButton: Bool = false

    @objc
    /// The title color for the "Edit" button.
    public var editButtonTitleColor: AirshipNativeColor? = nil

    @objc
    /// The dark mode title color for the "Edit" button.
    public var editButtonTitleColorDark: AirshipNativeColor? = nil

    @objc
    /// The title color for the "Cancel" button.
    public var cancelButtonTitleColor: AirshipNativeColor? = nil

    @objc
    /// The dark mode title color for the "Cancel" button.
    public var cancelButtonTitleColorDark: AirshipNativeColor? = nil

    @objc
    /// The title color for the "Done" button.
    public var backButtonColor: AirshipNativeColor? = nil

    @objc
    /// The dark mode title color for the "Done" button.
    public var backButtonColorDark: AirshipNativeColor? = nil

    @objc
    /// The navigation bar title
    public var navigationBarTitle: String? = nil

    @objc
    /// The background of the message list.
    public var messageListBackgroundColor: AirshipNativeColor? = nil

    @objc
    /// The dark mode background of the message list.
    public var messageListBackgroundColorDark: AirshipNativeColor? = nil

    @objc
    /// The background of the message list container.
    public var messageListContainerBackgroundColor: AirshipNativeColor? = nil

    @objc
    /// The dark mode background of the message list container.
    public var messageListContainerBackgroundColorDark: AirshipNativeColor? = nil

    @objc
    /// The background of the message view.
    public var messageViewBackgroundColor: AirshipNativeColor? = nil

    @objc
    /// The dark mode background of the message view.
    public var messageViewBackgroundColorDark: AirshipNativeColor? = nil

    @objc
    /// The background of the message view container.
    public var messageViewContainerBackgroundColor: AirshipNativeColor? = nil

    @objc
    /// The dark mode background of the message view container.
    public var messageViewContainerBackgroundColorDark: AirshipNativeColor? = nil

}
    

