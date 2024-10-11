/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

/// The Preference Center alert item view
public struct PreferenceCenterAlertView: View {

    /// The item's config
    public let item: PreferenceCenterConfig.Alert

    /// The preference state
    @ObservedObject
    public var state: PreferenceCenterState

    @Environment(\.airshipPreferenceCenterAlertStyle)
    private var style

    @Environment(\.airshipPreferenceCenterTheme)
    private var preferenceCenterTheme

    @Environment(\.colorScheme)
    private var colorScheme

    @State
    private var displayConditionsMet: Bool = true

    public init(item: PreferenceCenterConfig.Alert, state: PreferenceCenterState) {
        self.item = item
        self.state = state
    }

    @ViewBuilder
    public var body: some View {
        let configuration = PreferenceCenterAlertStyleConfiguration(
            item: self.item,
            state: self.state,
            displayConditionsMet: self.displayConditionsMet,
            preferenceCenterTheme: self.preferenceCenterTheme,
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
    /// Sets the alert style
    /// - Parameters:
    ///     - style: The style
    public func PreferenceCenterAlertStyle<S>(_ style: S) -> some View
    where S: PreferenceCenterAlertStyle {
        self.environment(
            \.airshipPreferenceCenterAlertStyle,
             AnyPreferenceCenterAlertStyle(style: style)
        )
    }
}

/// Preference Center alert style configuration
public struct PreferenceCenterAlertStyleConfiguration {
    /// The item config
    public let item: PreferenceCenterConfig.Alert

    /// The preference state
    public let state: PreferenceCenterState

    /// If the display conditions are met for this item
    public let displayConditionsMet: Bool

    /// The preference center theme
    public let preferenceCenterTheme: PreferenceCenterTheme

    /// The color scheme
    public let colorScheme: ColorScheme
}

/// Preference Center alert style
public protocol PreferenceCenterAlertStyle {
    associatedtype Body: View
    typealias Configuration = PreferenceCenterAlertStyleConfiguration
    func makeBody(configuration: Self.Configuration) -> Self.Body
}

extension PreferenceCenterAlertStyle
where Self == DefaultPreferenceCenterAlertStyle {

    /// Default style
    public static var defaultStyle: Self {
        return .init()
    }
}

/// The default Preference Center alert style
public struct DefaultPreferenceCenterAlertStyle: PreferenceCenterAlertStyle {
    static let titleAppearance = PreferenceCenterTheme.TextAppearance(
        font: .headline,
        color: .primary
    )

    static let subtitleAppearance = PreferenceCenterTheme.TextAppearance(
        font: .subheadline,
        color: .primary
    )

    @ViewBuilder
    public func makeBody(configuration: Configuration) -> some View {
        let colorScheme = configuration.colorScheme
        let item = configuration.item
        let itemTheme = configuration.preferenceCenterTheme.alert

        if configuration.displayConditionsMet {
            VStack(alignment: .center) {
                HStack(spacing: 16) {
                    if let url = item.display?.iconURL, !url.isEmpty {
                        AirshipAsyncImage(
                            url: url,
                            image: { image, _ in
                                image
                                    .resizable()
                                    .scaledToFit()
                            },
                            placeholder: {
                                return ProgressView()
                            }
                        )
                        .frame(width: 60, height: 60)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        if let title = item.display?.title {
                            Text(title)
                                .textAppearance(
                                    itemTheme?.titleAppearance,
                                    base: DefaultPreferenceCenterAlertStyle
                                        .titleAppearance,
                                    colorScheme: colorScheme
                                )
                        }

                        if let subtitle = item.display?.subtitle {
                            Text(subtitle)
                                .textAppearance(
                                    itemTheme?.subtitleAppearance,
                                    base: DefaultPreferenceCenterAlertStyle
                                        .subtitleAppearance,
                                    colorScheme: colorScheme
                                )
                        }

                        if let button = item.button {
                            Button(
                                action: {
                                    let actions = button.actionJSON
                                    Task {
                                        await ActionRunner.run(
                                            actionsPayload: actions,
                                            situation: .manualInvocation,
                                            metadata: [:]
                                        )
                                    }
                                },
                                label: {
                                    Text(button.text)
                                        .textAppearance(
                                            itemTheme?.buttonLabelAppearance,
                                            base: DefaultContactManagementSectionStyle.buttonLabelAppearance,
                                            colorScheme: colorScheme
                                        )
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(
                                                    colorScheme.airshipResolveColor(
                                                        light: itemTheme?.buttonBackgroundColor,
                                                        dark: itemTheme?.buttonBackgroundColorDark
                                                    ) ?? Color.blue
                                                )
                                        )
                                        .cornerRadius(8)
                                }
                            )
                            .optAccessibilityLabel(
                                string: button.contentDescription
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct AnyPreferenceCenterAlertStyle: PreferenceCenterAlertStyle {
    @ViewBuilder
    private var _makeBody: (Configuration) -> AnyView

    init<S: PreferenceCenterAlertStyle>(style: S) {
        _makeBody = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

struct PreferenceCenterAlertStyleKey: EnvironmentKey {
    static var defaultValue = AnyPreferenceCenterAlertStyle(style: .defaultStyle)
}

extension EnvironmentValues {
    var airshipPreferenceCenterAlertStyle: AnyPreferenceCenterAlertStyle {
        get { self[PreferenceCenterAlertStyleKey.self] }
        set { self[PreferenceCenterAlertStyleKey.self] = newValue }
    }
}
