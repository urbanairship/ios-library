/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

/// The channel subscription item view
struct ChannelSubscriptionView: View {

    /// The item's config
    public let item: PreferenceCenterConfig.ChannelSubscription

    // The preference state
    @ObservedObject
    public var state: PreferenceCenterState

    @Environment(\.airshipChannelSubscriptionViewStyle)
    private var style

    @Environment(\.airshipPreferenceCenterTheme)
    private var preferenceCenterTheme

    @State
    private var displayConditionsMet: Bool = true

    @ViewBuilder
    public var body: some View {
        let isSubscribed = state.makeBinding(channelListID: item.subscriptionID)

        let configuration = ChannelSubscriptionViewStyleConfiguration(
            item: self.item,
            state: self.state,
            displayConditionsMet: self.displayConditionsMet,
            preferenceCenterTheme: self.preferenceCenterTheme,
            isSubscribed: isSubscribed
        )

        style.makeBody(configuration: configuration)
            .preferenceConditions(
                self.item.conditions,
                binding: self.$displayConditionsMet
            )
    }
}


public extension View {
    /// Sets the channel subscription style
    /// - Parameters:
    ///     - style: The style
    func channelSubscriptionStyle<S>(_ style: S) -> some View where S : ChannelSubscriptionViewStyle {
        self.environment(\.airshipChannelSubscriptionViewStyle, AnyChannelSubscriptionViewStyle(style: style))
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
}

public protocol ChannelSubscriptionViewStyle {
    associatedtype Body: View
    typealias Configuration = ChannelSubscriptionViewStyleConfiguration
    func makeBody(configuration: Self.Configuration) -> Self.Body
}

public extension ChannelSubscriptionViewStyle where Self == DefaultChannelSubscriptionViewStyle {

    /// Default style
    static var defaultStyle: Self {
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
    
    @Environment(\.airshipPreferenceCenterTheme)
    private var preferenceCenterTheme

    @ViewBuilder
    public func makeBody(configuration: Configuration) -> some View {
        let item = configuration.item
        let itemTheme = configuration.preferenceCenterTheme.channelSubscription

        if (configuration.displayConditionsMet) {
            Toggle(isOn: configuration.isSubscribed) {
                VStack(alignment: .leading) {
                    if let title = item.display?.title {
                        Text(title)
                            .textAppearance(
                                itemTheme?.titleAppearance,
                                base: DefaultChannelSubscriptionViewStyle.titleAppearance
                            )
                    }

                    if let subtitle = item.display?.subtitle {
                        Text(subtitle)
                            .textAppearance(
                                itemTheme?.subtitleAppearance,
                                base: DefaultChannelSubscriptionViewStyle.subtitleAppearance
                            )
                    }
                }
            }
            .toggleStyle(tint: itemTheme?.toggleTintColor)
            .padding(.trailing, 2)
        }
    }
}

struct AnyChannelSubscriptionViewStyle: ChannelSubscriptionViewStyle {
    @ViewBuilder
    private var _makeBody: (Configuration) -> AnyView

    init<S: ChannelSubscriptionViewStyle>(style: S) {
        _makeBody = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

struct ChannelSubscriptionViewStyleKey: EnvironmentKey {
    static var defaultValue = AnyChannelSubscriptionViewStyle(style: .defaultStyle)
}

extension EnvironmentValues {
    var airshipChannelSubscriptionViewStyle: AnyChannelSubscriptionViewStyle {
        get { self[ChannelSubscriptionViewStyleKey.self] }
        set { self[ChannelSubscriptionViewStyleKey.self] = newValue }
    }
}
