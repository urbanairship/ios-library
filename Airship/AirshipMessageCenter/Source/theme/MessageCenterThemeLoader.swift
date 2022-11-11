/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

#if canImport(AirshipCore)
    import AirshipCore
#endif

struct MessageCenterThemeLoader {

    static let messageCenterFileName = "MessageCenterTheme"
    static let cellSeparatorStyleNoneKey = "none"

    static func defaultPlist() -> MessageCenterTheme? {
        if let _ = try? plistPath(
            file: messageCenterFileName,
            bundle: Bundle.main
        ) {
            do {
                return try fromPlist(messageCenterFileName)
            } catch {
                AirshipLogger.error(
                    "Unable to load message center theme \(error)"
                )
            }
        }

        return nil
    }

    static func fromPlist(_ file: String, bundle: Bundle = Bundle.main) throws
        -> MessageCenterTheme
    {
        let path = try plistPath(file: file, bundle: bundle)

        guard let data = FileManager.default.contents(atPath: path) else {
            throw AirshipErrors.error("Failed to load contents of theme.")
        }

        let decoder = PropertyListDecoder()

        let config = try decoder.decode(Config.self, from: data)
        return try config.toMessageCenterTheme()
    }

    static func plistPath(file: String, bundle: Bundle) throws -> String {
        guard let path = bundle.path(forResource: file, ofType: "plist"),
            FileManager.default.fileExists(atPath: path)
        else {
            throw AirshipErrors.error("File not found \(file).")
        }

        return path
    }

    fileprivate struct Config: Decodable {

        let tintColor: String?
        let refreshTintColor: String?

        let iconsEnabled: Bool?
        let placeholderIcon: String?

        let cellTitleFont: FontConfig?
        let cellDateFont: FontConfig?
        let cellColor: String?
        let cellTitleColor: String?
        let cellDateColor: String?
        let cellSeparatorStyle: String?
        let cellSeparatorColor: String?
        let cellTintColor: String?

        let unreadIndicatorColor: String?
        let selectAllButtonTitleColor: String?
        let deleteButtonTitleColor: String?
        let markAsReadButtonTitleColor: String?
        let editButtonTitleColor: String?
        let cancelButtonTitleColor: String?
        let backButtonColor: String?

        let navigationBarTitle: String?
    }

    struct FontConfig: Decodable {
        let fontName: String
        let fontSize: String
    }

}

extension String {

    fileprivate func toColor() -> Color {
        let colorString = self.trimmingCharacters(in: .whitespaces)
        if let uiColor = ColorUtils.color(colorString) {
            return Color(uiColor)
        }
        return Color(colorString)
    }

    fileprivate func toSeparatorStyle() -> SeparatorStyle {
        let separatorStyle = self.trimmingCharacters(in: .whitespaces)
        if separatorStyle == MessageCenterThemeLoader.cellSeparatorStyleNoneKey
        {
            return .none
        }
        return .singleLine
    }
}

extension MessageCenterThemeLoader.FontConfig {
    fileprivate func toFont() throws -> Font {
        guard
            let fontSize = Double(
                fontSize.trimmingCharacters(in: .whitespaces)
            ),
            fontSize > 0.0
        else {
            throw AirshipErrors.error(
                "Font size must represent a double greater than 0"
            )
        }

        return Font.custom(
            fontName.trimmingCharacters(in: .whitespaces),
            size: fontSize
        )
    }
}

extension MessageCenterThemeLoader.Config {
    fileprivate func toMessageCenterTheme() throws -> MessageCenterTheme {
        let theme = MessageCenterTheme()
        theme.refreshTintColor = self.refreshTintColor?.toColor()
        theme.iconsEnabled = self.iconsEnabled ?? false
        if let placeholderIcon = self.placeholderIcon {
            theme.placeholderIcon = Image(placeholderIcon)
        }
        theme.cellTitleFont = try self.cellTitleFont?.toFont()
        theme.cellDateFont = try? self.cellDateFont?.toFont()
        theme.cellColor = self.cellColor?.toColor()
        theme.cellTitleColor = self.cellTitleColor?.toColor()
        theme.cellDateColor = self.cellDateColor?.toColor()
        theme.cellSeparatorStyle = self.cellSeparatorStyle?.toSeparatorStyle()
        theme.cellSeparatorColor = self.cellSeparatorColor?.toColor()
        theme.cellTintColor = self.cellTintColor?.toColor()
        theme.unreadIndicatorColor = self.unreadIndicatorColor?.toColor()
        theme.selectAllButtonTitleColor = self.selectAllButtonTitleColor?
            .toColor()
        theme.deleteButtonTitleColor = self.deleteButtonTitleColor?.toColor()
        theme.markAsReadButtonTitleColor = self.markAsReadButtonTitleColor?
            .toColor()
        theme.editButtonTitleColor = self.editButtonTitleColor?.toColor()
        theme.cancelButtonTitleColor = self.cancelButtonTitleColor?.toColor()
        theme.backButtonColor = self.backButtonColor?.toColor()
        theme.navigationBarTitle = self.navigationBarTitle
        return theme
    }
}
