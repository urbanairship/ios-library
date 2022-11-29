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

    @Environment(\.airshipPrefenceCenterAlertStyle)
    private var style

    @Environment(\.airshipPreferenceCenterTheme)
    private var preferenceCenterTheme

    @State
    private var displayConditionsMet: Bool = true

    @ViewBuilder
    public var body: some View {
        let configuration = PrefernceCenterAlertStyleConfiguration(
            item: self.item,
            state: self.state,
            displayConditionsMet: self.displayConditionsMet,
            preferenceCenterTheme: self.preferenceCenterTheme
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
    public func prefernceCenterAlertStyle<S>(_ style: S) -> some View
    where S: PrefernceCenterAlertStyle {
        self.environment(
            \.airshipPrefenceCenterAlertStyle,
            AnyPrefernceCenterAlertStyle(style: style)
        )
    }
}

/// Preference Center alert style configuration
public struct PrefernceCenterAlertStyleConfiguration {
    /// The item config
    public let item: PreferenceCenterConfig.Alert

    /// The preference state
    public let state: PreferenceCenterState

    /// If the display conditions are met for this item
    public let displayConditionsMet: Bool

    /// The preference center theme
    public let preferenceCenterTheme: PreferenceCenterTheme
}

/// Preference Center alert style
public protocol PrefernceCenterAlertStyle {
    associatedtype Body: View
    typealias Configuration = PrefernceCenterAlertStyleConfiguration
    func makeBody(configuration: Self.Configuration) -> Self.Body
}

extension PrefernceCenterAlertStyle
where Self == DefaultPrefernceCenterAlertStyle {

    /// Default style
    public static var defaultStyle: Self {
        return .init()
    }
}

/// The default Preference Center alert style
public struct DefaultPrefernceCenterAlertStyle: PrefernceCenterAlertStyle {

    static let titleAppearance = PreferenceCenterTheme.TextAppearance(
        font: .headline,
        color: .primary
    )

    static let subtitleAppearance = PreferenceCenterTheme.TextAppearance(
        font: .subheadline,
        color: .primary
    )

    static let buttonLabelAppearance = PreferenceCenterTheme.TextAppearance(
        color: .white
    )

    @ViewBuilder
    public func makeBody(configuration: Configuration) -> some View {
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
                                    base: DefaultPrefernceCenterAlertStyle
                                        .titleAppearance
                                )
                        }

                        if let subtitle = item.display?.subtitle {
                            Text(subtitle)
                                .textAppearance(
                                    itemTheme?.subtitleAppearance,
                                    base: DefaultPrefernceCenterAlertStyle
                                        .subtitleAppearance
                                )
                        }

                        if let button = item.button {
                            Button(
                                action: {
                                    if let actions = button.actionJSON.unWrap()
                                        as? [String: Any]
                                    {
                                        ActionRunner.run(
                                            actionValues: actions,
                                            situation: .manualInvocation,
                                            metadata: nil,
                                            completionHandler: nil
                                        )
                                    }
                                },
                                label: {
                                    Text(button.text)
                                        .textAppearance(
                                            itemTheme?.buttonLabelAppearance,
                                            base:
                                                DefaultPrefernceCenterAlertStyle
                                                .buttonLabelAppearance
                                        )
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(
                                                    itemTheme?
                                                        .buttonBackgroundColor
                                                        ?? Color.blue
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

struct AnyPrefernceCenterAlertStyle: PrefernceCenterAlertStyle {
    @ViewBuilder
    private var _makeBody: (Configuration) -> AnyView

    init<S: PrefernceCenterAlertStyle>(style: S) {
        _makeBody = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

struct PrefernceCenterAlertStyleKey: EnvironmentKey {
    static var defaultValue = AnyPrefernceCenterAlertStyle(style: .defaultStyle)
}

extension EnvironmentValues {
    var airshipPrefenceCenterAlertStyle: AnyPrefernceCenterAlertStyle {
        get { self[PrefernceCenterAlertStyleKey.self] }
        set { self[PrefernceCenterAlertStyleKey.self] = newValue }
    }
}
