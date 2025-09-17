/* Copyright Airship and Contributors */

import Foundation
public import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Preference Center view style configuration
public struct PreferenceCenterContentStyleConfiguration: Sendable {
    /// The view's phase
    public let phase: PreferenceCenterContentPhase

    /// The preference center theme
    public let preferenceCenterTheme: PreferenceCenterTheme

    /// The colorScheme
    public let colorScheme: ColorScheme

    /// A block that can be called to refresh the view
    public let refresh: @MainActor @Sendable () -> Void
}

/// Preference Center view style
public protocol PreferenceCenterContentStyle: Sendable {
    associatedtype Body: View
    typealias Configuration = PreferenceCenterContentStyleConfiguration
    
    @preconcurrency @MainActor
    func makeBody(configuration: Self.Configuration) -> Self.Body
}

extension PreferenceCenterContentStyle
where Self == DefaultPreferenceCenterViewStyle {
    /// Default style
    public static var defaultStyle: Self {
        return .init()
    }
}

/// The default Preference Center view style
@MainActor @preconcurrency 
public struct DefaultPreferenceCenterViewStyle: PreferenceCenterContentStyle {

    @ViewBuilder
    private func makeProgressView(configuration: Configuration) -> some View {
        ProgressView()
            .frame(alignment: .center)
    }

    @ViewBuilder
    public func makeErrorView(configuration: Configuration) -> some View {
        let colorScheme = configuration.colorScheme
        let theme = configuration.preferenceCenterTheme.preferenceCenter
        let retry = theme?.retryButtonLabel ?? "ua_retry_button".preferenceCenterLocalizedString
        let errorMessage =
        theme?.retryMessage ?? "ua_preference_center_empty".preferenceCenterLocalizedString

        VStack {
            Text(errorMessage)
                .textAppearance(
                    theme?.retryMessageAppearance,
                    colorScheme: colorScheme
                )
                .padding()

            Button(
                action: {
                    configuration.refresh()
                },
                label: {
                    Text(retry)
                        .textAppearance(
                            theme?.retryButtonLabelAppearance,
                            base: PreferenceCenterTheme.TextAppearance(
                                color: colorScheme.airshipResolveColor(
                                    light: Color.white,
                                    dark: Color.black
                                )
                            ),
                            colorScheme: colorScheme
                        )
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(
                                    colorScheme.airshipResolveColor(
                                        light: theme?.retryButtonBackgroundColor,
                                        dark: theme?.retryButtonBackgroundColorDark
                                    ) ?? Color.blue
                                )
                        )
                        .cornerRadius(8)
                        .frame(minWidth: 44)
                }
            )
        }
    }

    @ViewBuilder
    @MainActor
    public func makePreferenceCenterView(
        configuration: Configuration,
        state: PreferenceCenterState
    ) -> some View {
        let colorScheme = configuration.colorScheme
        let theme = configuration.preferenceCenterTheme
        ScrollView {
            LazyVStack(alignment: .leading) {
                if let subtitle = state.config.display?.subtitle {
                    Text(subtitle)
                        .textAppearance(
                            theme.preferenceCenter?.subtitleAppearance,
                            base: PreferenceCenterDefaults.subtitleAppearance,
                            colorScheme: colorScheme
                        )
                        .padding(.bottom)
                }

                ForEach(0..<state.config.sections.count, id: \.self) { index in
                    self.section(
                        state.config.sections[index],
                        state: state,
                        isLast: index == state.config.sections.count - 1
                    )
                }
            }
            .padding()
            Spacer()
        }
    }

    @ViewBuilder
    @MainActor
    public func makeBody(configuration: Configuration) -> some View {
        let resolvedBackgroundColor: Color? = configuration.colorScheme.airshipResolveColor(
            light: configuration.preferenceCenterTheme.viewController?.backgroundColor,
            dark: configuration.preferenceCenterTheme.viewController?.backgroundColorDark
        )

        ZStack {
            if let resolvedBackgroundColor {
                resolvedBackgroundColor.ignoresSafeArea()
            }

            switch configuration.phase {
            case .loading:
                makeProgressView(configuration: configuration)
            case .error(_):
                makeErrorView(configuration: configuration)
            case .loaded(let state):
                makePreferenceCenterView(configuration: configuration, state: state)
            }
        }
    }

    @ViewBuilder
    @MainActor
    func section(
        _ section: PreferenceCenterConfig.Section,
        state: PreferenceCenterState,
        isLast: Bool
    ) -> some View {
        switch section {
        case .common(let section):
            CommonSectionView(
                section: section,
                state: state,
                isLast: isLast
            )
        case .labeledSectionBreak(let section):
            LabeledSectionBreakView(
                section: section,
                state: state
            )
        }
    }
}

struct AnyPreferenceCenterViewStyle: PreferenceCenterContentStyle {
    @ViewBuilder
    private var _makeBody: @MainActor @Sendable (Configuration) -> AnyView

    init<S: PreferenceCenterContentStyle>(style: S) {
        _makeBody = { @MainActor configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

struct PreferenceCenterViewStyleKey: EnvironmentKey {
    static let defaultValue = AnyPreferenceCenterViewStyle(style: .defaultStyle)
}

extension EnvironmentValues {
    var airshipPreferenceCenterStyle: AnyPreferenceCenterViewStyle {
        get { self[PreferenceCenterViewStyleKey.self] }
        set { self[PreferenceCenterViewStyleKey.self] = newValue }
    }
}

extension String {
    fileprivate func nullIfEmpty() -> String? {
        return self.isEmpty ? nil : self
    }
}
