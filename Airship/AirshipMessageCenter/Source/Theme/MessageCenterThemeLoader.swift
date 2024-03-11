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

    static func fromPlist(
        _ file: String,
        bundle: Bundle = Bundle.main
    ) throws -> MessageCenterTheme {
        let path = try plistPath(file: file, bundle: bundle)

        guard let data = FileManager.default.contents(atPath: path) else {
            throw AirshipErrors.error("Failed to load contents of theme.")
        }

        let decoder = PropertyListDecoder()

        let config = try decoder.decode(Config.self, from: data)
        return try config.toMessageCenterTheme(bundle: bundle)
    }

    static func plistPath(file: String, bundle: Bundle) throws -> String {
        guard let path = bundle.path(forResource: file, ofType: "plist"),
              FileManager.default.fileExists(atPath: path)
        else {
            throw AirshipErrors.error("File not found \(file).")
        }

        return path
    }

    internal struct Config: Decodable {
        let tintColor: String?
        let tintColorDark: String?
        let refreshTintColor: String?
        let refreshTintColorDark: String?

        let iconsEnabled: Bool?
        let placeholderIcon: String?

        let cellTitleFont: FontConfig?
        let cellDateFont: FontConfig?
        let cellColor: String?
        let cellColorDark: String?
        let cellTitleColor: String?
        let cellTitleColorDark: String?
        let cellDateColor: String?
        let cellDateColorDark: String?
        let cellSeparatorStyle: String?
        let cellSeparatorColor: String?
        let cellSeparatorColorDark: String?
        let cellTintColor: String?
        let cellTintColorDark: String?

        let unreadIndicatorColor: String?
        let unreadIndicatorColorDark: String?
        let selectAllButtonTitleColor: String?
        let selectAllButtonTitleColorDark: String?
        let deleteButtonTitleColor: String?
        let deleteButtonTitleColorDark: String?
        let markAsReadButtonTitleColor: String?
        let markAsReadButtonTitleColorDark: String?
        let hideDeleteButton: Bool?
        let editButtonTitleColor: String?
        let editButtonTitleColorDark: String?
        let cancelButtonTitleColor: String?
        let cancelButtonTitleColorDark: String?
        let backButtonColor: String?
        let backButtonColorDark: String?

        let navigationBarTitle: String?
    }

    struct FontConfig: Decodable {
        let fontName: String
        let fontSize: FontSize

        enum FontSize: Decodable {
            case string(String)
            case cgFloat(CGFloat)

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let value = try? container.decode(String.self) {
                    self = .string(value)
                } else if let value = try? container.decode(CGFloat.self) {
                    self = .cgFloat(value)
                } else {
                    throw AirshipErrors.error(
                        "Font size must be able to be parsed into a String or CGFloat"
                    )
                }
            }

            var size: CGFloat {
                switch self {
                case .string(let value):
                    return CGFloat(Double(value) ?? 0.0)
                case .cgFloat(let value):
                    return value
                }
            }
        }
    }
}

extension String {
    internal func toColor(_ bundle:Bundle = Bundle.main) -> Color {
        let colorString = self.trimmingCharacters(in: .whitespaces)

        // Regular expression pattern for hex color strings
        /// Optional # with 6-8 hexadecimal characters case insensitive
        let hexPattern = "^#?([A-Fa-f0-9]{8}|[A-Fa-f0-9]{6})$"

        /// If named color doesn't exist (parses to clear) and string follows hex pattern - assume it's a hex color
        if let _ = colorString.range(of: hexPattern, options: .regularExpression) {
            if let uiColor = AirshipColorUtils.color(colorString) {
                return Color(uiColor)
            }
        }

        // The color string is not in hex format or named color exists for this string
        return Color(colorString, bundle: bundle)
    }

    internal func toSeparatorStyle() -> SeparatorStyle {
        let separatorStyle = self.trimmingCharacters(in: .whitespaces)
        if separatorStyle == MessageCenterThemeLoader.cellSeparatorStyleNoneKey
        {
            return .none
        }
        return .singleLine
    }
}

extension Color {
    var isClear: Bool {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var opacity: CGFloat = 0

        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &opacity)

        return opacity == 0.0
    }
}

extension MessageCenterThemeLoader.FontConfig {
    internal func toFont() throws -> Font {
        let size: CGFloat
        let zeroSizeError = AirshipErrors.error("Font size must represent a valid number greater than 0")

        switch fontSize {
        case .string(let value):
            guard let fontSize = Double(value), fontSize > 0.0 else {
                throw zeroSizeError
            }
            size = CGFloat(fontSize)
        case .cgFloat(let value):
            guard value > 0.0 else {
                throw zeroSizeError
            }
            size = value
        }

        return Font.custom(fontName.trimmingCharacters(in: .whitespaces), size: size)
    }
}

extension MessageCenterThemeLoader.Config {
    internal func toMessageCenterTheme(bundle: Bundle = Bundle.main) throws -> MessageCenterTheme {
        var theme = MessageCenterTheme()
        theme.refreshTintColor = self.refreshTintColor?.toColor(bundle)
        theme.refreshTintColorDark = self.refreshTintColorDark?.toColor(bundle)
        theme.iconsEnabled = self.iconsEnabled ?? false
        if let placeholderIcon = self.placeholderIcon {
            theme.placeholderIcon = Image(placeholderIcon)
        }
        theme.cellTitleFont = try self.cellTitleFont?.toFont()
        theme.cellDateFont = try? self.cellDateFont?.toFont()
        theme.cellColor = self.cellColor?.toColor(bundle)
        theme.cellColorDark = self.cellColorDark?.toColor(bundle)
        theme.cellTitleColor = self.cellTitleColor?.toColor(bundle)
        theme.cellTitleColorDark = self.cellTitleColorDark?.toColor(bundle)
        theme.cellDateColor = self.cellDateColor?.toColor(bundle)
        theme.cellDateColorDark = self.cellDateColorDark?.toColor(bundle)
        theme.cellSeparatorStyle = self.cellSeparatorStyle?.toSeparatorStyle()
        theme.cellSeparatorColor = self.cellSeparatorColor?.toColor(bundle)
        theme.cellSeparatorColorDark = self.cellSeparatorColorDark?.toColor(bundle)
        theme.cellTintColor = self.cellTintColor?.toColor(bundle)
        theme.cellTintColorDark = self.cellTintColorDark?.toColor(bundle)
        theme.unreadIndicatorColor = self.unreadIndicatorColor?.toColor(bundle)
        theme.unreadIndicatorColorDark = self.unreadIndicatorColorDark?.toColor(bundle)
        theme.selectAllButtonTitleColor = self.selectAllButtonTitleColor?
            .toColor(bundle)
        theme.selectAllButtonTitleColorDark = self.selectAllButtonTitleColorDark?
            .toColor(bundle)
        theme.deleteButtonTitleColor = self.deleteButtonTitleColor?.toColor(bundle)
        theme.deleteButtonTitleColorDark = self.deleteButtonTitleColorDark?
            .toColor(bundle)
        theme.markAsReadButtonTitleColor = self.markAsReadButtonTitleColor?
            .toColor(bundle)
        theme.markAsReadButtonTitleColorDark = self
            .markAsReadButtonTitleColorDark?.toColor(bundle)
        theme.hideDeleteButton = self.hideDeleteButton ?? false
        theme.editButtonTitleColor = self.editButtonTitleColor?.toColor(bundle)
        theme.editButtonTitleColorDark = self.editButtonTitleColorDark?
            .toColor(bundle)
        theme.cancelButtonTitleColor = self.cancelButtonTitleColor?.toColor(bundle)
        theme.cancelButtonTitleColorDark = self.cancelButtonTitleColorDark?
            .toColor(bundle)
        theme.backButtonColor = self.backButtonColor?.toColor(bundle)
        theme.backButtonColorDark = self.backButtonColorDark?.toColor(bundle)
        theme.navigationBarTitle = self.navigationBarTitle
        return theme
    }
}
