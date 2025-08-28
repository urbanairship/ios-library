/* Copyright Airship and Contributors */


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

        let messageListBackgroundColor: String?
        let messageListBackgroundColorDark: String?
        let messageListContainerBackgroundColor: String?
        let messageListContainerBackgroundColorDark: String?

        let messageViewBackgroundColor: String?
        let messageViewBackgroundColorDark: String?
        let messageViewContainerBackgroundColor: String?
        let messageViewContainerBackgroundColorDark: String?

        let navigationBarTitle: String?
    }

    struct FontConfig: Decodable {
        let fontName: String
        let fontSize: FontSize

        enum FontSize: Decodable {
            case string(String)
            case cgFloat(CGFloat)

            init(from decoder: any Decoder) throws {
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
        theme.refreshTintColor = self.refreshTintColor?.airshipToColor(bundle)
        theme.refreshTintColorDark = self.refreshTintColorDark?.airshipToColor(bundle)
        theme.iconsEnabled = self.iconsEnabled ?? false
        if let placeholderIcon = self.placeholderIcon {
            theme.placeholderIcon = Image(placeholderIcon)
        }
        theme.cellTitleFont = try? self.cellTitleFont?.toFont()
        theme.cellDateFont = try? self.cellDateFont?.toFont()
        theme.cellColor = self.cellColor?.airshipToColor(bundle)
        theme.cellColorDark = self.cellColorDark?.airshipToColor(bundle)
        theme.cellTitleColor = self.cellTitleColor?.airshipToColor(bundle)
        theme.cellTitleColorDark = self.cellTitleColorDark?.airshipToColor(bundle)
        theme.cellDateColor = self.cellDateColor?.airshipToColor(bundle)
        theme.cellDateColorDark = self.cellDateColorDark?.airshipToColor(bundle)
        theme.cellSeparatorStyle = self.cellSeparatorStyle?.toSeparatorStyle()
        theme.cellSeparatorColor = self.cellSeparatorColor?.airshipToColor(bundle)
        theme.cellSeparatorColorDark = self.cellSeparatorColorDark?.airshipToColor(bundle)
        theme.cellTintColor = self.cellTintColor?.airshipToColor(bundle)
        theme.cellTintColorDark = self.cellTintColorDark?.airshipToColor(bundle)
        theme.unreadIndicatorColor = self.unreadIndicatorColor?.airshipToColor(bundle)
        theme.unreadIndicatorColorDark = self.unreadIndicatorColorDark?.airshipToColor(bundle)
        theme.selectAllButtonTitleColor = self.selectAllButtonTitleColor?
            .airshipToColor(bundle)
        theme.selectAllButtonTitleColorDark = self.selectAllButtonTitleColorDark?
            .airshipToColor(bundle)
        theme.deleteButtonTitleColor = self.deleteButtonTitleColor?.airshipToColor(bundle)
        theme.deleteButtonTitleColorDark = self.deleteButtonTitleColorDark?
            .airshipToColor(bundle)
        theme.markAsReadButtonTitleColor = self.markAsReadButtonTitleColor?
            .airshipToColor(bundle)
        theme.markAsReadButtonTitleColorDark = self
            .markAsReadButtonTitleColorDark?.airshipToColor(bundle)
        theme.hideDeleteButton = self.hideDeleteButton ?? false
        theme.editButtonTitleColor = self.editButtonTitleColor?.airshipToColor(bundle)
        theme.editButtonTitleColorDark = self.editButtonTitleColorDark?
            .airshipToColor(bundle)
        theme.cancelButtonTitleColor = self.cancelButtonTitleColor?.airshipToColor(bundle)
        theme.cancelButtonTitleColorDark = self.cancelButtonTitleColorDark?
            .airshipToColor(bundle)
        theme.backButtonColor = self.backButtonColor?.airshipToColor(bundle)
        theme.backButtonColorDark = self.backButtonColorDark?.airshipToColor(bundle)
        theme.navigationBarTitle = self.navigationBarTitle
        theme.messageListBackgroundColor = self.messageListBackgroundColor?.airshipToColor(bundle)
        theme.messageListBackgroundColorDark = self.messageListBackgroundColorDark?.airshipToColor(bundle)
        theme.messageListContainerBackgroundColor = self.messageListContainerBackgroundColor?.airshipToColor(bundle)
        theme.messageListContainerBackgroundColorDark = self.messageListContainerBackgroundColorDark?.airshipToColor(bundle)
        theme.messageViewBackgroundColor = self.messageViewBackgroundColor?.airshipToColor(bundle)
        theme.messageViewBackgroundColorDark = self.messageViewBackgroundColorDark?.airshipToColor(bundle)
        theme.messageViewContainerBackgroundColor = self.messageViewContainerBackgroundColor?.airshipToColor(bundle)
        theme.messageViewContainerBackgroundColorDark = self.messageViewContainerBackgroundColorDark?.airshipToColor(bundle)
        return theme
    }
}

fileprivate extension String {
    func toSeparatorStyle() -> SeparatorStyle {
        let separatorStyle = self.trimmingCharacters(in: .whitespaces)
        if separatorStyle == MessageCenterThemeLoader.cellSeparatorStyleNoneKey
        {
            return .none
        }
        return .singleLine
    }
}
