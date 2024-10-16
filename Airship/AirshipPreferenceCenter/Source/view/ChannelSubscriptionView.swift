/* Copyright Airship and Contributors */

import Foundation
public import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

/// The channel subscription item view
public struct ChannelSubscriptionView: View {

    /// The item's config
    public let item: PreferenceCenterConfig.ChannelSubscription

    // The preference state
    @ObservedObject
    public var state: PreferenceCenterState

    @Environment(\.airshipChannelSubscriptionViewStyle)
    private var style

    @Environment(\.airshipPreferenceCenterTheme)
    private var preferenceCenterTheme

    @Environment(\.colorScheme)
    private var colorScheme

    @State
    private var displayConditionsMet: Bool = true

    public init(item: PreferenceCenterConfig.ChannelSubscription, state: PreferenceCenterState) {
        self.item = item
        self.state = state
    }
    
    @ViewBuilder
    public var body: some View {
        let isSubscribed = state.makeBinding(channelListID: item.subscriptionID)

        let configuration = ChannelSubscriptionViewStyleConfiguration(
            item: self.item,
            state: self.state,
            displayConditionsMet: self.displayConditionsMet,
            preferenceCenterTheme: self.preferenceCenterTheme,
            isSubscribed: isSubscribed,
            colorScheme: self.colorScheme
        )

        style.makeBody(configuration: configuration)
            .preferenceConditions(
                self.item.conditions,
                binding: self.$displayConditionsMet
            )
    }
}

extension View {
    /// Sets the channel subscription style
    /// - Parameters:
    ///     - style: The style
    public func channelSubscriptionStyle<S>(_ style: S) -> some View
    where S: ChannelSubscriptionViewStyle {
        self.environment(
            \.airshipChannelSubscriptionViewStyle,
            AnyChannelSubscriptionViewStyle(style: style)
        )
    }
}

/// Channel subscription item view style configuration
public struct ChannelSubscriptionViewStyleConfiguration {
    /// The item's config
    public let item: PreferenceCenterConfig.ChannelSubscription

    /// The preference state
    public let state: PreferenceCenterState

    /// If the display conditions are met for this item
    public let displayConditionsMet: Bool

    /// The preference center theme
    public let preferenceCenterTheme: PreferenceCenterTheme

    /// The item's subscription binding
    public let isSubscribed: Binding<Bool>

    /// Color scheme
    public let colorScheme: ColorScheme
}

public protocol ChannelSubscriptionViewStyle: Sendable {
    associatedtype Body: View
    typealias Configuration = ChannelSubscriptionViewStyleConfiguration
    
    @MainActor
    func makeBody(configuration: Self.Configuration) -> Self.Body
}

extension ChannelSubscriptionViewStyle
where Self == DefaultChannelSubscriptionViewStyle {

    /// Default style
    public static var defaultStyle: Self {
        return .init()
    }
}

/// The default channel subscription view style
public struct DefaultChannelSubscriptionViewStyle: ChannelSubscriptionViewStyle {
    static let titleAppearance = PreferenceCenterTheme.TextAppearance(
        font: .headline,
        color: .primary
    )

    static let subtitleAppearance = PreferenceCenterTheme.TextAppearance(
        font: .subheadline,
        color: .primary
    )


    @ViewBuilder
    @MainActor
    public func makeBody(configuration: Configuration) -> some View {
        let item = configuration.item
        let itemTheme = configuration.preferenceCenterTheme.channelSubscription
        let colorScheme = configuration.colorScheme
        let resolvedToggleTintColor: Color? = colorScheme.airshipResolveColor(light:  itemTheme?.toggleTintColor, dark:  itemTheme?.toggleTintColorDark)

        if configuration.displayConditionsMet {
            Toggle(isOn: configuration.isSubscribed) {
                VStack(alignment: .leading) {
                    if let title = item.display?.title {
                        Text(title)
                            .textAppearance(
                                itemTheme?.titleAppearance,
                                base: DefaultChannelSubscriptionViewStyle
                                    .titleAppearance,
                                colorScheme: colorScheme
                            )
                            .accessibilityAddTraits(.isHeader)
                    }

                    if let subtitle = item.display?.subtitle {
                        Text(subtitle)
                            .textAppearance(
                                itemTheme?.subtitleAppearance,
                                base: DefaultChannelSubscriptionViewStyle
                                    .subtitleAppearance,
                                colorScheme: colorScheme
                            )

                    }
                }
            }
            .toggleStyle(tint: resolvedToggleTintColor)
            .padding(.trailing, 2)
        }
    }
}

struct AnyChannelSubscriptionViewStyle: ChannelSubscriptionViewStyle {
    @ViewBuilder
    private let _makeBody: @MainActor @Sendable (Configuration) -> AnyView

    init<S: ChannelSubscriptionViewStyle>(style: S) {
        _makeBody = { @MainActor configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

struct ChannelSubscriptionViewStyleKey: EnvironmentKey {
    static let defaultValue = AnyChannelSubscriptionViewStyle(
        style: .defaultStyle
    )
}

extension EnvironmentValues {
    var airshipChannelSubscriptionViewStyle: AnyChannelSubscriptionViewStyle {
        get { self[ChannelSubscriptionViewStyleKey.self] }
        set { self[ChannelSubscriptionViewStyleKey.self] = newValue }
    }
}
