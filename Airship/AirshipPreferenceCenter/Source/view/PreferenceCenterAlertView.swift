/* Copyright Airship and Contributors */


public import SwiftUI

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
public protocol PreferenceCenterAlertStyle: Sendable {
    associatedtype Body: View
    typealias Configuration = PreferenceCenterAlertStyleConfiguration
    
    @MainActor
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
    @ViewBuilder
    @MainActor
    public func makeBody(configuration: Configuration) -> some View {
        let colorScheme = configuration.colorScheme
        let item = configuration.item
        let itemTheme = configuration.preferenceCenterTheme.alert

        if configuration.displayConditionsMet {
            VStack(alignment: .center) {
                HStack(alignment: .top) {
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
                        .padding()
                    }

                    VStack(alignment: .leading) {
                        if let title = item.display?.title {
                            Text(title)
                                .textAppearance(
                                    itemTheme?.titleAppearance,
                                    base: PreferenceCenterDefaults.titleAppearance,
                                    colorScheme: colorScheme
                                )
                        }

                        if let subtitle = item.display?.subtitle {
                            Text(subtitle)
                                .textAppearance(
                                    itemTheme?.subtitleAppearance,
                                    base: PreferenceCenterDefaults.subtitleAppearance,
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
                                            base: PreferenceCenterDefaults.buttonLabelAppearance,
                                            colorScheme: colorScheme
                                        )
                                        .padding(.horizontal)
                                        .padding(.vertical, PreferenceCenterDefaults.smallPadding)
#if !os(tvOS)

                                        .background(
                                            Capsule()
                                                .fill(
                                                    colorScheme.airshipResolveColor(
                                                        light: itemTheme?.buttonBackgroundColor,
                                                        dark: itemTheme?.buttonBackgroundColorDark
                                                    ) ?? Color.blue
                                                )
                                        )
                                        .frame(minHeight: 44)

#endif
                                }
                            )
#if os(tvOS)
                            .tint(colorScheme.airshipResolveColor(
                                light: itemTheme?.buttonBackgroundColor,
                                dark: itemTheme?.buttonBackgroundColorDark
                            ) ?? Color.blue)
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
#else
                            .clipShape(Capsule())
#endif
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
    private var _makeBody: @MainActor @Sendable (Configuration) -> AnyView

    init<S: PreferenceCenterAlertStyle>(style: S) {
        _makeBody = { @MainActor configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

struct PreferenceCenterAlertStyleKey: EnvironmentKey {
    static let defaultValue = AnyPreferenceCenterAlertStyle(style: .defaultStyle)
}

extension EnvironmentValues {
    var airshipPreferenceCenterAlertStyle: AnyPreferenceCenterAlertStyle {
        get { self[PreferenceCenterAlertStyleKey.self] }
        set { self[PreferenceCenterAlertStyleKey.self] = newValue }
    }
}
