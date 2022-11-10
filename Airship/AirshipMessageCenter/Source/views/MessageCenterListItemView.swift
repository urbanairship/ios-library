/* Copyright Urban Airship and Contributors */

import Foundation
import SwiftUI

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

public extension View {
    /// Sets the list item style
    /// - Parameters:
    ///     - style: The style
    func setMessageCenterItemViewStyle<S>(_ style: S) -> some View where S : MessageCenterListItemViewStyle {
        self.environment(\.airshipMessageCenterListItemStyle, AnyListItemViewStyle(style: style))
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

public extension MessageCenterListItemViewStyle where Self == DefaultListItemViewStyle {

    /// Default style
    static var defaultStyle: Self {
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

fileprivate struct MessageCenterListContentView: View {
    
    @Environment(\.airshipMessageCenterTheme)
    private var theme
    
    let message: MessageCenterMessage
    
    private var placeHolder: some View {
        var image = Image(systemName: "photo")
        if let placeholderIcon = theme.placeholderIcon {
            image = placeholderIcon
        }
        return image
            .resizable()
            .scaledToFit()
            .foregroundColor(.primary)
            .frame(width: theme.iconsEnabled ? 60 : 20.0)
            .opacity(theme.iconsEnabled ? 1.0 : 0.0)
        
    }

    @ViewBuilder
    func makeIcon(_ listIcon: String?) -> some View {
        if let listIcon = listIcon {
            AirshipAsyncImage(url: listIcon) { image, _ in
                image.resizable()
                    .scaledToFit()
                    .frame(width: theme.iconsEnabled ? 60 : 20.0)
            } placeholder: {
                return self.placeHolder
            }
        } else {
            self.placeHolder
        }
    }

    @ViewBuilder
    func makeUnreadIndicator(_ unread: Bool) -> some View {
        if (unread) {
            Image(systemName: "circle.fill")
                .foregroundColor(
                    theme.unreadIndicatorColor ??  theme.cellTintColor
                )
                .frame(width: 8, height: 8)
        }
    }
    
    @ViewBuilder
    func makeTitle(_ title: String) -> some View {
        Text(title)
            .font(theme.cellTitleFont)
            .foregroundColor(theme.cellTitleColor)
    }
    
    @ViewBuilder
    func makeSubtitle(_ subtitle: String?) -> some View {
        if let subtitle = subtitle {
            Text(subtitle)
                .font(.subheadline)
        }
    }
    
    @ViewBuilder
    func makeMessageSentDate(_ messageSent: Date) -> some View {
        let messageSent = messageSent
        Text(messageSent, style: .date)
            .font(theme.cellDateFont)
            .foregroundColor(theme.cellDateColor)
    }
    
    @ViewBuilder
    var body: some View {
        let message = message
        HStack(alignment: .top, spacing: 5) {
            makeIcon(message.listIcon)
            VStack(alignment: .leading, spacing: 5) {
                makeTitle(message.title)
                makeSubtitle(message.subtitle)
                makeMessageSentDate(message.sentDate)
            }
            Spacer()
        }
        .overlay(makeUnreadIndicator(message.unread), alignment: .topLeading)
        .padding(8)
    }
}

