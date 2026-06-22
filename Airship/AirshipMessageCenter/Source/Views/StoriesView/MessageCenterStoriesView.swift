// Copyright Urban Airship and Contributors

import Foundation
public import SwiftUI

import AirshipCore

/// A horizontal strip of message center items shown as circular “story” avatars.
///
/// Displays messages from the Airship message center in a stories row:
/// each message is a circle with an optional list icon, a border that indicates read vs. unread,
/// and a tap action.
///
/// Use ``View/messageCenterStoryViewStyle(_:)`` to customize how each story circle is drawn;
/// the default style uses ``View/messageCenterTheme(_:)`` for colors and placeholder icon.
///
/// Example:
/// ```swift
/// MessageCenterStoriesView(
///     filter: myPredicate,
///     sort: myComparator,
///     onMessageSelected: { message in
///         // Navigate to message or show detail
///     }
/// )
/// ```
@_spi(AirshipPreview)
public struct MessageCenterStoriesView: View {
    private static let preferredSize: CGFloat = 80
    private static let borderWidth: CGFloat = 3
    private static let imageInset: CGFloat = 2

    @StateObject
    private var viewModel: MessageCenterStoriesViewModel
    private var onMessageSelected: (MessageCenterMessage) -> Void
    
    private let emptyView: () -> AnyView

    /// Creates the stories view with optional inbox filter and sort, and a selection callback.
    ///
    /// - Parameters:
    ///   - filter: Optional predicate to show only messages that match. Omit for all messages.
    ///   - sort: Optional comparator to order messages. Omit for default inbox order.
    ///   - onMessageSelected: Closure invoked when the user taps a story circle; receives the selected message.
    ///   - placeholder: View to show when there are no messages.
    public init(
        filter: (any MessageCenterPredicate)? = nil,
        sort: ComparePredicate? = nil,
        onMessageSelected: @escaping (MessageCenterMessage) -> Void,
        placeholder: @escaping () -> any View = { EmptyView() }
    ) {
        self._viewModel = StateObject(wrappedValue: MessageCenterStoriesViewModel(filter: filter, sort: sort))
        self.onMessageSelected = onMessageSelected
        self.emptyView = { AnyView(erasing: placeholder()) }
    }

    init(
        viewModel: MessageCenterStoriesViewModel,
        onMessageSelected: @escaping (MessageCenterMessage) -> Void,
        noMessagesView: @escaping () -> some View = { EmptyView() }
    ) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.onMessageSelected = onMessageSelected
        self.emptyView = { AnyView(erasing: noMessagesView()) }
    }

    @Environment(\.airshipMessageCenterStoryViewStyle)
    private var storyViewStyle

    public var body: some View {
        //TODO: localization
        if viewModel.isLoaded {
            if viewModel.stories.isEmpty {
                emptyView()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.stories) { message in
                            let configuration = StoryViewStyleConfiguration(message: message)
                            storyViewStyle.makeBody(configuration: configuration)
                                .onTapGesture {
                                    onMessageSelected(message)
                                }
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
        } else {
            ProgressView()
                .frame(height: Self.preferredSize)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Story view style

/// The configuration for a Message Center story (circle) view.
public struct StoryViewStyleConfiguration: Sendable {
    /// The message associated with the story.
    public let message: MessageCenterMessage
}

/// A protocol that defines the style for a Message Center story view.
public protocol MessageCenterStoryViewStyle: Sendable {
    associatedtype Body: View

    typealias Configuration = StoryViewStyleConfiguration

    /// Creates the view body for the story item.
    /// - Parameter configuration: The configuration for the story (message).
    /// - Returns: The view body.
    func makeBody(configuration: Self.Configuration) -> Self.Body
}

extension MessageCenterStoryViewStyle where Self == DefaultStoryViewStyle {
    /// The default story view style.
    public static var defaultStyle: Self {
        .init()
    }
}

/// The default style for a Message Center story view (circle with border and image).
public struct DefaultStoryViewStyle: MessageCenterStoryViewStyle {
    @ViewBuilder
    public func makeBody(configuration: Configuration) -> some View {
        MessageCenterStoryContentView(configuration: configuration)
    }
}

struct AnyStoryViewStyle: MessageCenterStoryViewStyle {
    @ViewBuilder
    private let _makeBody: @Sendable (StoryViewStyleConfiguration) -> AnyView

    init<S: MessageCenterStoryViewStyle>(style: S) {
        _makeBody = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    @ViewBuilder
    public func makeBody(configuration: StoryViewStyleConfiguration) -> some View {
        _makeBody(configuration)
    }
}

struct StoryViewStyleKey: EnvironmentKey {
    static let defaultValue = AnyStoryViewStyle(style: .defaultStyle)
}

extension EnvironmentValues {
    /// The Message Center story view style.
    var airshipMessageCenterStoryViewStyle: AnyStoryViewStyle {
        get { self[StoryViewStyleKey.self] }
        set { self[StoryViewStyleKey.self] = newValue }
    }
}

extension View {
    /// Sets the story view style for the Message Center stories strip.
    /// - Parameter style: The style to apply to each story circle.
    public func messageCenterStoryViewStyle<S: MessageCenterStoryViewStyle>(_ style: S) -> some View {
        environment(\.airshipMessageCenterStoryViewStyle, AnyStoryViewStyle(style: style))
    }
}

// MARK: - Default story content (theme-driven)

private struct MessageCenterStoryContentView: View {
    private static let placeHolderImageName: String = "photo"
    private static let preferredSize: CGFloat = 80
    private static let borderWidth: CGFloat = 3
    private static let imageInset: CGFloat = 2

    @Environment(\.airshipMessageCenterTheme)
    private var theme

    @Environment(\.colorScheme)
    private var colorScheme

    let configuration: StoryViewStyleConfiguration

    var body: some View {
        let message = configuration.message
        let borderColor = borderColor(for: message)

        ZStack {
            Circle()
                .strokeBorder(borderColor, lineWidth: Self.borderWidth)

            Circle()
                .foregroundStyle(imageBackgroundColor)
                .padding(Self.borderWidth + Self.imageInset)
                .overlay {
                    messageImage(message: message)
                        .aspectRatio(contentMode: .fit)
                        .clipShape(Circle())
                }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(idealHeight: Self.preferredSize)
    }

    @ViewBuilder
    private func messageImage(message: MessageCenterMessage) -> some View {
        if let listIcon = message.listIcon {
            AirshipAsyncImage(url: listIcon) { image, _ in
                image.resizable()
                    .scaledToFit()
            } placeholder: {
                placeholderImage()
            }
        } else {
            placeholderImage()
        }
    }

    @ViewBuilder
    private func placeholderImage() -> some View {
        let image = theme.placeholderIcon ?? Image(systemName: Self.placeHolderImageName)
        image
            .resizable()
            .scaledToFill()
            .foregroundColor(.secondary)
    }

    private func borderColor(for message: MessageCenterMessage) -> Color {
        if message.unread {
            return colorScheme.airshipResolveColor(
                light: theme.unreadIndicatorColor,
                dark: theme.unreadIndicatorColorDark
            ) ?? colorScheme.airshipResolveColor(
                light: theme.cellTintColor,
                dark: theme.cellTintColorDark
            ) ?? .blue
        } else {
            return colorScheme.airshipResolveColor(
                light: theme.cellSeparatorColor,
                dark: theme.cellSeparatorColorDark
            ) ?? .gray.opacity(0.7)
        }
    }

    private var imageBackgroundColor: Color {
        colorScheme.airshipResolveColor(
            light: theme.cellColor,
            dark: theme.cellColorDark
        ) ?? .secondary
    }
}

#Preview {
    let dummyURL = URL(string: "https://example.com")!
    let messages = (0..<6).map { index in
        MessageCenterMessage(
            title: "Story \(index + 1)",
            id: "msg-\(index)",
            contentType: .html,
            extra: [:],
            bodyURL: dummyURL,
            expirationDate: nil,
            messageReporting: nil,
            unread: index % 2 == 0,
            sentDate: Date(),
            messageURL: dummyURL,
            rawMessageObject: [:]
        )
    }
    
    let viewModel = MessageCenterStoriesViewModel(previewStories: messages)

    MessageCenterStoriesView(viewModel: viewModel) { message in
        print("Selected: \(message.title)")
    }
    .frame(height: 80)
}
