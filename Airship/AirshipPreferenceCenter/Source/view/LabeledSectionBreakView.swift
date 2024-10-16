/* Copyright Airship and Contributors */

import Foundation
public import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Labeled section break view
public struct LabeledSectionBreakView: View {

    /// The section's config
    public let section: PreferenceCenterConfig.LabeledSectionBreak

    /// The preference state
    @ObservedObject
    public var state: PreferenceCenterState

    @Environment(\.airshipLabeledSectionBreakStyle)
    private var style

    @Environment(\.airshipPreferenceCenterTheme)
    private var preferenceCenterTheme

    @Environment(\.colorScheme)
    private var colorScheme

    @State
    private var displayConditionsMet: Bool = true

    public init(section: PreferenceCenterConfig.LabeledSectionBreak, state: PreferenceCenterState) {
        self.section = section
        self.state = state
    }

    @ViewBuilder
    public var body: some View {
        let configuration = LabeledSectionBreakStyleConfiguration(
            section: self.section,
            state: self.state,
            displayConditionsMet: self.displayConditionsMet,
            preferenceCenterTheme: self.preferenceCenterTheme,
            colorScheme: self.colorScheme
        )

        style.makeBody(configuration: configuration)
            .preferenceConditions(
                self.section.conditions,
                binding: self.$displayConditionsMet
            )
    }
}

extension View {
    /// Sets the labeled section break style
    /// - Parameters:
    ///     - style: The style
    public func labeledSectionBreakStyle<S>(_ style: S) -> some View
    where S: LabeledSectionBreakStyle {
        self.environment(
            \.airshipLabeledSectionBreakStyle,
            AnyLabeledSectionBreakStyle(style: style)
        )
    }
}

/// The labeled section break style configuration
public struct LabeledSectionBreakStyleConfiguration {
    /// The section config
    public let section: PreferenceCenterConfig.LabeledSectionBreak

    /// The preference state
    public let state: PreferenceCenterState

    /// If the display conditions are met for this item
    public let displayConditionsMet: Bool

    /// The preference center theme
    public let preferenceCenterTheme: PreferenceCenterTheme

    /// The color scheme
    public let colorScheme: ColorScheme
}

/// Labeled section break style
public protocol LabeledSectionBreakStyle: Sendable {
    associatedtype Body: View
    typealias Configuration = LabeledSectionBreakStyleConfiguration
    func makeBody(configuration: Self.Configuration) -> Self.Body
}

extension LabeledSectionBreakStyle
where Self == DefaultLabeledSectionBreakStyle {

    /// Default style
    public static var defaultStyle: Self {
        return .init()
    }
}

/// Default labeled section break style
public struct DefaultLabeledSectionBreakStyle: LabeledSectionBreakStyle {

    @ViewBuilder
    public func makeBody(configuration: Configuration) -> some View {
        let colorScheme = configuration.colorScheme
        let section = configuration.section
        let sectionTheme = configuration.preferenceCenterTheme
            .labeledSectionBreak
        let backgroundColor = colorScheme.airshipResolveColor(light: sectionTheme?.backgroundColor, dark: sectionTheme?.backgroundColorDark) ?? .gray

        if configuration.displayConditionsMet {
            Text(section.display?.title ?? "")
                .textAppearance(
                    sectionTheme?.titleAppearance,
                    base: PreferenceCenterTheme.TextAppearance(
                        font: .system(size: 14),
                        color: Color.black,
                        colorDark: Color.white
                    ),
                    colorScheme: colorScheme
                )
                .padding(.vertical, 2)
                .padding(.horizontal, 4)
                .background(backgroundColor)
        }
    }
}

struct AnyLabeledSectionBreakStyle: LabeledSectionBreakStyle {
    @ViewBuilder
    private let _makeBody: @Sendable (Configuration) -> AnyView

    init<S: LabeledSectionBreakStyle>(style: S) {
        _makeBody = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

struct LabeledSectionBreakStyleKey: EnvironmentKey {
    static let defaultValue = AnyLabeledSectionBreakStyle(style: .defaultStyle)
}

extension EnvironmentValues {
    var airshipLabeledSectionBreakStyle: AnyLabeledSectionBreakStyle {
        get { self[LabeledSectionBreakStyleKey.self] }
        set { self[LabeledSectionBreakStyleKey.self] = newValue }
    }
}
