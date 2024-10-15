/* Copyright Urban Airship and Contributors */

import Foundation
public import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

struct MessageCenterListItemView: View {

    @Environment(\.airshipMessageCenterListItemStyle)
    private var itemStyle

    @ObservedObject
    var viewModel: MessageCenterListItemViewModel

    @ViewBuilder
    var body: some View {
        let configuration = ListItemViewStyleConfiguration(
            message: self.viewModel.message
        )
        itemStyle.makeBody(configuration: configuration)
    }
}

extension View {
    /// Sets the list item style
    /// - Parameters:
    ///     - style: The style
    public func setMessageCenterItemViewStyle<S>(_ style: S) -> some View
    where S: MessageCenterListItemViewStyle {
        self.environment(
            \.airshipMessageCenterListItemStyle,
            AnyListItemViewStyle(style: style)
        )
    }
}

/// Message center list item view style configuration
public struct ListItemViewStyleConfiguration {
    public let message: MessageCenterMessage
}

public protocol MessageCenterListItemViewStyle {
    associatedtype Body: View

    typealias Configuration = ListItemViewStyleConfiguration

    func makeBody(configuration: Self.Configuration) -> Self.Body
}

extension MessageCenterListItemViewStyle
where Self == DefaultListItemViewStyle {

    /// Default style
    public static var defaultStyle: Self {
        return .init()
    }
}

/// The default list item view style
public struct DefaultListItemViewStyle: MessageCenterListItemViewStyle {
    @ViewBuilder
    public func makeBody(configuration: Configuration) -> some View {
        MessageCenterListContentView(message: configuration.message)
    }
}

struct AnyListItemViewStyle: MessageCenterListItemViewStyle {
    @ViewBuilder
    private var _makeBody: (Configuration) -> AnyView

    init<S: MessageCenterListItemViewStyle>(style: S) {
        _makeBody = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

struct ListItemViewStyleKey: EnvironmentKey {
    static var defaultValue = AnyListItemViewStyle(style: .defaultStyle)
}

extension EnvironmentValues {
    var airshipMessageCenterListItemStyle: AnyListItemViewStyle {
        get { self[ListItemViewStyleKey.self] }
        set { self[ListItemViewStyleKey.self] = newValue }
    }
}

private struct MessageCenterListContentView: View {

    private static let iconWidth: Double = 60.0
    private static let placeHolderImageName: String = "photo"
    private static let unreadIndicatorImageName: String = "circle.fill"
    private static let unreadIndicatorSize: Double = 8.0
    private static let noIconSpacerWidth: Double = 20.0

    @Environment(\.colorScheme)
    private var colorScheme
    
    @Environment(\.airshipMessageCenterTheme)
    private var theme

    let message: MessageCenterMessage

    @ViewBuilder
    func makeIcon() -> some View {
        if let listIcon = self.message.listIcon {
            AirshipAsyncImage(url: listIcon) { image, _ in
                image.resizable()
                    .scaledToFit()
                    .frame(width: MessageCenterListContentView.iconWidth)
            } placeholder: {
                return makeImagePlaceHolder()
            }
        } else {
            makeImagePlaceHolder()
        }
    }

    private func makeImagePlaceHolder() -> some View {
        let placeHolderImage = theme.placeholderIcon ?? Image(
            systemName: MessageCenterListContentView.placeHolderImageName
        )

        return placeHolderImage
            .resizable()
            .scaledToFit()
            .foregroundColor(.primary)
            .frame(width: MessageCenterListContentView.iconWidth)
    }

    @ViewBuilder
    func makeUnreadIndicator() -> some View {
        let foregroundColor = colorScheme.resolveColor(light: theme.unreadIndicatorColor, dark: theme.unreadIndicatorColorDark) ?? colorScheme.resolveColor(light: theme.cellTintColor, dark: theme.cellTintColorDark)

        if self.message.unread {
            Image(systemName: MessageCenterListContentView.unreadIndicatorImageName)
                .foregroundColor(
                    foregroundColor
                )
                .frame(
                    width: MessageCenterListContentView.unreadIndicatorSize,
                    height: MessageCenterListContentView.unreadIndicatorSize
                )
        }
    }

    @ViewBuilder
    func makeMessageInfo() -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(self.message.title)
                .font(theme.cellTitleFont)
                .foregroundColor(colorScheme.resolveColor(light: theme.cellTitleColor, dark: theme.cellTitleColorDark))
                .accessibilityHidden(true)

            if let subtitle = self.message.subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .accessibilityHidden(true)

            }

            Text(self.message.sentDate, style: .date)
                .font(theme.cellDateFont)
                .foregroundColor(colorScheme.resolveColor(light: theme.cellDateColor, dark: theme.cellDateColorDark))
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    var body: some View {
        HStack(alignment: .top, spacing: 5) {
            if (theme.iconsEnabled) {
                makeIcon()
                    .padding(.trailing)
                makeMessageInfo()
            } else {
                Spacer().frame(
                    width: MessageCenterListContentView.noIconSpacerWidth
                )
                makeMessageInfo()
            }
            Spacer()
        }
        .overlay(makeUnreadIndicator(), alignment: .topLeading)
        .padding(8)
    }
}
