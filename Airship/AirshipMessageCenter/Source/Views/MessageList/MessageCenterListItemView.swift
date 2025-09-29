/* Copyright Airship and Contributors */

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
    /// Sets the list item style for the Message Center.
    /// - Parameters:
    ///     - style: The style to apply.
    public func messageCenterItemViewStyle<S>(
        _ style: S
    ) -> some View where S: MessageCenterListItemViewStyle {
        self.environment(
            \.airshipMessageCenterListItemStyle,
            AnyListItemViewStyle(style: style)
        )
    }
}

/// The configuration for a Message Center list item view.
public struct ListItemViewStyleConfiguration {
    /// The message associated with the list item.
    public let message: MessageCenterMessage
}

/// A protocol that defines the style for a Message Center list item view.
public protocol MessageCenterListItemViewStyle: Sendable {
    associatedtype Body: View

    typealias Configuration = ListItemViewStyleConfiguration

    /// Creates the view body for the list item.
    /// - Parameters:
    ///   - configuration: The configuration for the list item.
    /// - Returns: The view body.
    func makeBody(configuration: Self.Configuration) -> Self.Body
}

extension MessageCenterListItemViewStyle where Self == DefaultListItemViewStyle {
    /// The default list item style.
    public static var defaultStyle: Self {
        return .init()
    }
}

/// The default style for a Message Center list item view.
public struct DefaultListItemViewStyle: MessageCenterListItemViewStyle {
    @ViewBuilder
    /// Creates the view body for the list item.
    /// - Parameters:
    ///   - configuration: The configuration for the list item.
    /// - Returns: The view body.
    public func makeBody(configuration: Configuration) -> some View {
        MessageCenterListContentView(message: configuration.message)
    }
}

struct AnyListItemViewStyle: MessageCenterListItemViewStyle {
    @ViewBuilder
    private let _makeBody: @Sendable (Configuration) -> AnyView

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
    static let defaultValue = AnyListItemViewStyle(style: .defaultStyle)
}

extension EnvironmentValues {
    var airshipMessageCenterListItemStyle: AnyListItemViewStyle {
        get { self[ListItemViewStyleKey.self] }
        set { self[ListItemViewStyleKey.self] = newValue }
    }
}

private struct MessageCenterListContentView: View {

#if os(tvOS)
    private static let iconWidth: Double = 100.0
    private static let noIconSpacerWidth: Double = 30.0
#else
    private static let iconWidth: Double = 60.0
    private static let noIconSpacerWidth: Double = 20.0
#endif

    private static let unreadIndicatorSize: Double = 8.0
    private static let placeHolderImageName: String = "photo"
    private static let unreadIndicatorImageName: String = "circle.fill"


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
        let foregroundColor = colorScheme.airshipResolveColor(
            light: theme.unreadIndicatorColor,
            dark: theme.unreadIndicatorColorDark
        ) ?? colorScheme.airshipResolveColor(
            light: theme.cellTintColor,
            dark: theme.cellTintColorDark
        )

        Image(systemName: MessageCenterListContentView.unreadIndicatorImageName)
            .foregroundColor(
                foregroundColor
            )
            .frame(
                width: MessageCenterListContentView.unreadIndicatorSize,
                height: MessageCenterListContentView.unreadIndicatorSize
            )
    }

    @ViewBuilder
    func makeMessageInfo() -> some View {
        VStack(alignment: .leading) {
            Text(self.message.title)
                .font(theme.cellTitleFont)
                .foregroundColor(colorScheme.airshipResolveColor(light: theme.cellTitleColor, dark: theme.cellTitleColorDark))
                .accessibilityHidden(true)

            if let subtitle = self.message.subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .accessibilityHidden(true)

            }

            Text(self.message.sentDate, style: .date)
                .font(theme.cellDateFont)
                .foregroundColor(colorScheme.airshipResolveColor(light: theme.cellDateColor, dark: theme.cellDateColorDark))
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    var body: some View {
        HStack(alignment: .top) {
            if (!theme.iconsEnabled) {
                makeIcon()
#if !os(tvOS)
                    .padding(.trailing)
#endif
                    .overlay(makeUnreadIndicator(), alignment: .topLeading)
            } else {
                Spacer().frame(
                    width: MessageCenterListContentView.noIconSpacerWidth
                )
                .overlay(makeUnreadIndicator(), alignment: .topLeading)
            }

            makeMessageInfo()
            Spacer()
        }
#if os(tvOS)
        .padding()
#else
        .padding(8)
#endif
    }
}
