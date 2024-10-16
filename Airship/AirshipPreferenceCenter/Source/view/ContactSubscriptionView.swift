/* Copyright Airship and Contributors */

import Foundation
public import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

/// The contact subscription item view
public struct ContactSubscriptionView: View {

    /// The item's config
    public let item: PreferenceCenterConfig.ContactSubscription

    /// The preference state
    @ObservedObject
    public var state: PreferenceCenterState

    @Environment(\.airshipContactSubscriptionViewStyle)
    private var style

    @Environment(\.airshipPreferenceCenterTheme)
    private var preferenceCenterTheme

    @Environment(\.colorScheme)
    private var colorScheme

    @State
    private var displayConditionsMet: Bool = true

    public init(item: PreferenceCenterConfig.ContactSubscription, state: PreferenceCenterState) {
        self.item = item
        self.state = state
    }

    @ViewBuilder
    public var body: some View {
        let isSubscribed = state.makeBinding(
            contactListID: item.subscriptionID,
            scopes: item.scopes
        )

        let configuration = ContactSubscriptionViewStyleConfiguration(
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
    /// Sets the contact subscription style
    /// - Parameters:
    ///     - style: The style
    public func contactSubscriptionStyle<S>(_ style: S) -> some View
    where S: ContactSubscriptionViewStyle {
        self.environment(
            \.airshipContactSubscriptionViewStyle,
            AnyContactSubscriptionViewStyle(style: style)
        )
    }
}

/// Contact subscription item view style configuration
public struct ContactSubscriptionViewStyleConfiguration {
    /// The item's config
    public let item: PreferenceCenterConfig.ContactSubscription

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

/// Contact subcription view style
public protocol ContactSubscriptionViewStyle: Sendable {
    associatedtype Body: View
    typealias Configuration = ContactSubscriptionViewStyleConfiguration
    
    @MainActor
    func makeBody(configuration: Self.Configuration) -> Self.Body
}

extension ContactSubscriptionViewStyle
where Self == DefaultContactSubscriptionViewStyle {
    /// Default style
    public static var defaultStyle: Self {
        return .init()
    }
}

/// Default contact subscription view style
public struct DefaultContactSubscriptionViewStyle: ContactSubscriptionViewStyle {
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
        let colorScheme = configuration.colorScheme
        let item = configuration.item
        let itemTheme = configuration.preferenceCenterTheme.contactSubscription

        if configuration.displayConditionsMet {
            Toggle(isOn: configuration.isSubscribed) {
                VStack(alignment: .leading) {
                    if let title = item.display?.title {
                        Text(title)
                            .textAppearance(
                                itemTheme?.titleAppearance,
                                base: DefaultContactSubscriptionViewStyle
                                    .titleAppearance,
                                colorScheme: colorScheme
                            ).accessibilityAddTraits(.isHeader)
                    }

                    if let subtitle = item.display?.subtitle {
                        Text(subtitle)
                            .textAppearance(
                                itemTheme?.subtitleAppearance,
                                base: DefaultContactSubscriptionViewStyle
                                    .subtitleAppearance,
                                colorScheme: colorScheme
                            )
                    }
                }
            }
            .toggleStyle(tint: colorScheme.airshipResolveColor(light: itemTheme?.toggleTintColor, dark: itemTheme?.toggleTintColorDark))
            .padding(.trailing, 2)
        }
    }
}

struct AnyContactSubscriptionViewStyle: ContactSubscriptionViewStyle {
    @ViewBuilder
    private let _makeBody: @MainActor @Sendable (Configuration) -> AnyView

    init<S: ContactSubscriptionViewStyle>(style: S) {
        _makeBody = { @MainActor configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

struct ContactSubscriptionViewStyleKey: EnvironmentKey {
    static let defaultValue = AnyContactSubscriptionViewStyle(
        style: .defaultStyle
    )
}

extension EnvironmentValues {
    var airshipContactSubscriptionViewStyle: AnyContactSubscriptionViewStyle {
        get { self[ContactSubscriptionViewStyleKey.self] }
        set { self[ContactSubscriptionViewStyleKey.self] = newValue }
    }
}
