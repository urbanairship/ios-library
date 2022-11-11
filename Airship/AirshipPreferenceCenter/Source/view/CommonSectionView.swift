/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

#if canImport(AirshipCore)
    import AirshipCore
#endif

/// Common section item view
public struct CommonSectionView: View {

    /// The section's config
    public let section: PreferenceCenterConfig.CommonSection

    /// The preference state
    @ObservedObject
    public var state: PreferenceCenterState

    @Environment(\.airshipCommonSectionViewStyle)
    private var style

    @Environment(\.airshipPreferenceCenterTheme)
    private var preferenceCenterTheme

    @State
    private var displayConditionsMet: Bool = true

    @ViewBuilder
    public var body: some View {
        let configuration = CommonSectionViewStyleConfiguration(
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
    /// Sets the common section style
    /// - Parameters:
    ///     - style: The style
    public func commonSectionViewStyle<S>(_ style: S) -> some View
    where S: CommonSectionViewStyle {
        self.environment(
            \.airshipCommonSectionViewStyle,
            AnyCommonSectionViewStyle(style: style)
        )
    }
}

/// Common section style configuration
public struct CommonSectionViewStyleConfiguration {
    /// The section config
    public let section: PreferenceCenterConfig.CommonSection

    /// The preference state
    public let state: PreferenceCenterState

    /// If the display conditions are met for this item
    public let displayConditionsMet: Bool

    /// The preference center theme
    public let preferenceCenterTheme: PreferenceCenterTheme
}

/// Common section view style
public protocol CommonSectionViewStyle {
    associatedtype Body: View
    typealias Configuration = CommonSectionViewStyleConfiguration
    func makeBody(configuration: Self.Configuration) -> Self.Body
}

extension CommonSectionViewStyle where Self == DefaultCommonSectionViewStyle {

    /// The default style
    public static var defaultStyle: Self {
        return .init()
    }
}

/// The default comon section view style
public struct DefaultCommonSectionViewStyle: CommonSectionViewStyle {

    static let titleAppearance = PreferenceCenterTheme.TextAppearance(
        font: .system(size: 18).bold(),
        color: .primary
    )

    static let subtitleAppearance = PreferenceCenterTheme.TextAppearance(
        font: .system(size: 14),
        color: .secondary
    )

    @ViewBuilder
    public func makeBody(configuration: Configuration) -> some View {
        let section = configuration.section
        let sectionTheme = configuration.preferenceCenterTheme.commonSection

        if configuration.displayConditionsMet {
            VStack(alignment: .leading) {
                if section.display?.title != nil
                    || section.display?.subtitle != nil
                {
                    if let title = section.display?.title {
                        Text(title)
                            .textAppearance(
                                sectionTheme?.titleAppearance,
                                base: DefaultCommonSectionViewStyle
                                    .titleAppearance
                            )
                    }

                    if let subtitle = section.display?.subtitle {
                        Text(subtitle)
                            .textAppearance(
                                sectionTheme?.subtitleAppearance,
                                base: DefaultCommonSectionViewStyle
                                    .subtitleAppearance
                            )
                    }

                    Divider()
                }

                ForEach(0..<section.items.count, id: \.self) { index in
                    makeItem(section.items[index], state: configuration.state)
                }
            }
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    func makeItem(
        _ item: PreferenceCenterConfig.Item,
        state: PreferenceCenterState
    ) -> some View {
        switch item {
        case .alert(let item):
            PreferenceCenterAlertView(item: item, state: state)
        case .channelSubscription(let item):
            ChannelSubscriptionView(item: item, state: state)
            Divider()
        case .contactSubscription(let item):
            ContactSubscriptionView(item: item, state: state)
            Divider()
        case .contactSubscriptionGroup(let item):
            ContactSubscriptionGroupView(item: item, state: state)
            Divider()
        }
    }
}

struct AnyCommonSectionViewStyle: CommonSectionViewStyle {
    @ViewBuilder
    private var _makeBody: (Configuration) -> AnyView

    init<S: CommonSectionViewStyle>(style: S) {
        _makeBody = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

struct CommonSectionViewStyleKey: EnvironmentKey {
    static var defaultValue = AnyCommonSectionViewStyle(
        style: DefaultCommonSectionViewStyle()
    )
}

extension EnvironmentValues {
    var airshipCommonSectionViewStyle: AnyCommonSectionViewStyle {
        get { self[CommonSectionViewStyleKey.self] }
        set { self[CommonSectionViewStyleKey.self] = newValue }
    }
}
