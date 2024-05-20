/* Copyright Urban Airship and Contributors */

import Foundation
import SwiftUI
import UIKit

#if canImport(AirshipCore)
import AirshipCore
#endif

public enum SeparatorStyle {
    case none
    case singleLine
}

/// Model object representing a custom theme to be applied to the default message center.
///
/// To customize the message center theme:
///
///     MessageCenterView(
///         controller: messageCenterController
///     )
///     .messageCenterTheme(theme)
///
public struct MessageCenterTheme {

    /// The tint color of the "pull to refresh" control
    public var refreshTintColor: Color? = nil

    /// The dark mode tint color of the "pull to refresh" control
    public var refreshTintColorDark: Color? = nil

    /// Whether icons are enabled. Defaults to `NO`.
    public var iconsEnabled: Bool = false

    /// An optional placeholder image to use when icons haven't fully loaded.
    public var placeholderIcon: Image? = nil

    /// The font to use for message cell titles.
    public var cellTitleFont: Font? = .headline

    /// The font to use for message cell dates.
    public var cellDateFont: Font? = .subheadline

    /// The regular color for message cells
    public var cellColor: Color? = nil

    /// The dark mode color for message cells
    public var cellColorDark: Color? = nil

    /// The regular color for message cell titles.
    public var cellTitleColor: Color? = .primary

    /// The dark mode color for message cell titles.
    public var cellTitleColorDark: Color? = nil

    /// The regular color for message cell dates.
    public var cellDateColor: Color? = .secondary

    /// The dark mode color for message cell dates.
    public var cellDateColorDark: Color? = nil

    /// The message cell separator style.
    public var cellSeparatorStyle: SeparatorStyle?

    /// The message cell separator color.
    public var cellSeparatorColor: Color? = Color(UIColor.separator)

    /// The dark mode message cell separator color.
    public var cellSeparatorColorDark: Color? = nil

    /// The message cell tint color.
    public var cellTintColor: Color? = nil

    /// The dark mode message cell tint color.
    public var cellTintColorDark: Color? = nil

    /// The background color for the unread indicator.
    public var unreadIndicatorColor: Color? = nil

    /// The dark mode background color for the unread indicator.
    public var unreadIndicatorColorDark: Color? = nil

    /// The title color for the "Select All" button.
    public var selectAllButtonTitleColor: Color? = nil

    /// The dark mode title color for the "Select All" button.
    public var selectAllButtonTitleColorDark: Color? = nil

    /// The title color for the "Delete" button.
    public var deleteButtonTitleColor: Color? = nil

    /// The dark mode title color for the "Delete" button.
    public var deleteButtonTitleColorDark: Color? = nil

    /// The title color for the "Mark Read" button.
    public var markAsReadButtonTitleColor: Color? = nil

    /// The dark mode title color for the "Mark Read" button.
    public var markAsReadButtonTitleColorDark: Color? = nil

    /// Whether the delete message button from the message view is enabled. Defaults to `NO`.
    public var hideDeleteButton: Bool? = false

    /// The title color for the "Edit" button.
    public var editButtonTitleColor: Color? = nil

    /// The dark mode title color for the "Edit" button.
    public var editButtonTitleColorDark: Color? = nil

    /// The title color for the "Cancel" button.
    public var cancelButtonTitleColor: Color? = nil

    /// The dark mode title color for the "Cancel" button.
    public var cancelButtonTitleColorDark: Color? = nil

    /// The title color for the "Done" button.
    public var backButtonColor: Color? = nil

    /// The dark mode title color for the "Done" button.
    public var backButtonColorDark: Color? = nil

    /// The navigation bar title
    public var navigationBarTitle: String? = nil

    /// The background of the message list.
    public var messageListBackgroundColor: Color? = nil

    /// The dark mode background of the message list.
    public var messageListBackgroundColorDark: Color? = nil

    /// The background of the message list container.
    public var messageListContainerBackgroundColor: Color? = nil

    /// The dark mode background of the message list container.
    public var messageListContainerBackgroundColorDark: Color? = nil

    public init(
        refreshTintColor: Color? = nil,
        refreshTintColorDark: Color? = nil,
        iconsEnabled: Bool = false,
        placeholderIcon: Image? = nil,
        cellTitleFont: Font? = nil,
        cellDateFont: Font? = nil,
        cellColor: Color? = nil,
        cellColorDark: Color? = nil,
        cellTitleColor: Color? = nil,
        cellTitleColorDark: Color? = nil,
        cellDateColor: Color? = nil,
        cellDateColorDark: Color? = nil,
        cellSeparatorStyle: SeparatorStyle? = nil,
        cellSeparatorColor: Color? = nil,
        cellSeparatorColorDark: Color? = nil,
        cellTintColor: Color? = nil,
        cellTintColorDark: Color? = nil,
        unreadIndicatorColor: Color? = nil,
        unreadIndicatorColorDark: Color? = nil,
        selectAllButtonTitleColor: Color? = nil,
        selectAllButtonTitleColorDark: Color? = nil,
        deleteButtonTitleColor: Color? = nil,
        deleteButtonTitleColorDark: Color? = nil,
        markAsReadButtonTitleColor: Color? = nil,
        markAsReadButtonTitleColorDark: Color? = nil,
        hideDeleteButton: Bool? = nil,
        editButtonTitleColor: Color? = nil,
        editButtonTitleColorDark: Color? = nil,
        cancelButtonTitleColor: Color? = nil,
        cancelButtonTitleColorDark: Color? = nil,
        backButtonColor: Color? = nil,
        backButtonColorDark: Color? = nil,
        navigationBarTitle: String? = nil,
        messageListBackgroundColor: Color? = nil,
        messageListBackgroundColorDark: Color? = nil,
        messageListContainerBackgroundColor: Color? = nil,
        messageListContainerBackgroundColorDark: Color? = nil
    ) {
        self.refreshTintColor = refreshTintColor
        self.refreshTintColorDark = refreshTintColorDark
        self.iconsEnabled = iconsEnabled
        self.placeholderIcon = placeholderIcon
        self.cellTitleFont = cellTitleFont
        self.cellDateFont = cellDateFont
        self.cellColor = cellColor
        self.cellColorDark = cellColorDark
        self.cellTitleColor = cellTitleColor
        self.cellTitleColorDark = cellTitleColorDark
        self.cellDateColor = cellDateColor
        self.cellDateColorDark = cellDateColorDark
        self.cellSeparatorStyle = cellSeparatorStyle
        self.cellSeparatorColor = cellSeparatorColor
        self.cellSeparatorColorDark = cellSeparatorColorDark
        self.cellTintColor = cellTintColor
        self.cellTintColorDark = cellTintColorDark
        self.unreadIndicatorColor = unreadIndicatorColor
        self.unreadIndicatorColorDark = unreadIndicatorColorDark
        self.selectAllButtonTitleColor = selectAllButtonTitleColor
        self.selectAllButtonTitleColorDark = selectAllButtonTitleColorDark
        self.deleteButtonTitleColor = deleteButtonTitleColor
        self.deleteButtonTitleColorDark = deleteButtonTitleColorDark
        self.markAsReadButtonTitleColor = markAsReadButtonTitleColor
        self.markAsReadButtonTitleColorDark = markAsReadButtonTitleColorDark
        self.hideDeleteButton = hideDeleteButton
        self.editButtonTitleColor = editButtonTitleColor
        self.editButtonTitleColorDark = editButtonTitleColorDark
        self.cancelButtonTitleColor = cancelButtonTitleColor
        self.cancelButtonTitleColorDark = cancelButtonTitleColorDark
        self.backButtonColor = backButtonColor
        self.backButtonColorDark = backButtonColorDark
        self.navigationBarTitle = navigationBarTitle
        self.messageListBackgroundColor = messageListBackgroundColor
        self.messageListBackgroundColorDark = messageListBackgroundColorDark
        self.messageListContainerBackgroundColor = messageListContainerBackgroundColor
        self.messageListContainerBackgroundColorDark = messageListContainerBackgroundColorDark
    }
}

extension View {
    /// Overrides the message center theme
    /// - Parameters:
    ///     - theme: The message center theme
    public func messageCenterTheme(_ theme: MessageCenterTheme) -> some View {
        environment(\.airshipMessageCenterTheme, theme)
    }
}

struct MessageCenterThemeKey: EnvironmentKey {
    static let defaultValue = MessageCenterTheme()
}

extension EnvironmentValues {
    /// Airship message center theme environment value
    public var airshipMessageCenterTheme: MessageCenterTheme {
        get { self[MessageCenterThemeKey.self] }
        set { self[MessageCenterThemeKey.self] = newValue }
    }
}

extension MessageCenterTheme {
    /// Loads a message center theme from a plist file
    /// - Parameters:
    ///     - plist: The name of the plist in the bundle
    public static func fromPlist(_ plist: String) throws -> MessageCenterTheme {
        return try MessageCenterThemeLoader.fromPlist(plist)
    }
}
