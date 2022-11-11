/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

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

    @State
    private var displayConditionsMet: Bool = true

    @ViewBuilder
    public var body: some View {
        let configuration = LabeledSectionBreakStyleConfiguration(
            section: self.section,
            state: self.state,
            displayConditionsMet: self.displayConditionsMet,
            preferenceCenterTheme: self.preferenceCenterTheme
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
}

/// Labeled section break style
public protocol LabeledSectionBreakStyle {
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

    static let defaultTitleAppearance = PreferenceCenterTheme.TextAppearance(
        font: .system(size: 14),
        color: .white
    )

    @ViewBuilder
    public func makeBody(configuration: Configuration) -> some View {
        let section = configuration.section
        let sectionTheme = configuration.preferenceCenterTheme
            .labeledSectionBreak

        if configuration.displayConditionsMet {
            Text(section.display?.title ?? "")
                .textAppearance(
                    sectionTheme?.titleAppearance,
                    base: DefaultLabeledSectionBreakStyle.defaultTitleAppearance
                )
                .padding(.vertical, 2)
                .padding(.horizontal, 4)
                .background(sectionTheme?.backgroundColor ?? .gray)
        }
    }
}

struct AnyLabeledSectionBreakStyle: LabeledSectionBreakStyle {
    @ViewBuilder
    private var _makeBody: (Configuration) -> AnyView

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
    static var defaultValue = AnyLabeledSectionBreakStyle(style: .defaultStyle)
}

extension EnvironmentValues {
    var airshipLabeledSectionBreakStyle: AnyLabeledSectionBreakStyle {
        get { self[LabeledSectionBreakStyleKey.self] }
        set { self[LabeledSectionBreakStyleKey.self] = newValue }
    }
}
