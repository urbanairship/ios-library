/* Copyright Airship and Contributors */

import Foundation
public import SwiftUI

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

    @Environment(\.colorScheme)
    private var colorScheme

    init(
        section: PreferenceCenterConfig.CommonSection,
        state: PreferenceCenterState
    ) {
        self.section = section
        self.state = state
    }
    
    @ViewBuilder
    public var body: some View {
        let configuration = CommonSectionViewStyleConfiguration(
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

    /// The color scheme
    public let colorScheme: ColorScheme
}

/// Common section view style
public protocol CommonSectionViewStyle: Sendable {
    associatedtype Body: View
    typealias Configuration = CommonSectionViewStyleConfiguration
    
    @MainActor
    func makeBody(configuration: Self.Configuration) -> Self.Body
}

extension CommonSectionViewStyle where Self == DefaultCommonSectionViewStyle {

    /// The default style
    public static var defaultStyle: Self {
        return .init()
    }
}

/// The default common section view style
public struct DefaultCommonSectionViewStyle: CommonSectionViewStyle {

    @ViewBuilder
    @MainActor
    public func makeBody(configuration: Configuration) -> some View {
        let section = configuration.section
        let sectionTheme = configuration.preferenceCenterTheme.commonSection
        let colorScheme = configuration.colorScheme

        if configuration.displayConditionsMet {
            VStack(alignment: .leading) {
                Spacer()
                if section.display?.title?.isEmpty == false || section.display?.subtitle?.isEmpty == false {
                    VStack(alignment: .leading) {
                        if let title = section.display?.title {
                            Text(title)
                                .textAppearance(
                                    sectionTheme?.titleAppearance,
                                    base: PreferenceCenterDefaults.sectionTitleAppearance,
                                    colorScheme: colorScheme
                                )
                                .accessibilityAddTraits(.isHeader)
                        }

                        if let subtitle = section.display?.subtitle {
                            Text(subtitle)
                                .textAppearance(
                                    sectionTheme?.subtitleAppearance,
                                    base: PreferenceCenterDefaults.sectionSubtitleAppearance,
                                    colorScheme: colorScheme
                                )
                        }
                    }
                    .padding(.bottom, PreferenceCenterDefaults.smallPadding)
                }

                ForEach(0..<section.items.count, id: \.self) { index in
                    makeItem(
                        section.items[index],
                        state: configuration.state
                    )
                }
            }
#if os(tvOS)
            .focusSection()
#endif

            Divider().padding(.vertical)
            
        }
    }

    @ViewBuilder
    @MainActor
    func makeItem(
        _ item: PreferenceCenterConfig.Item,
        state: PreferenceCenterState
    ) -> some View {
        switch item {
        case .alert(let item):
            PreferenceCenterAlertView(item: item, state: state).transition(.opacity)
        case .channelSubscription(let item):
            ChannelSubscriptionView(item: item, state: state)
        case .contactSubscription(let item):
            ContactSubscriptionView(item: item, state: state)
        case .contactSubscriptionGroup(let item):
            ContactSubscriptionGroupView(item: item, state: state)
        case .contactManagement(let item):
            PreferenceCenterContactManagementView(
                item: item,
                state: state
            )
        }
    }
}

struct AnyCommonSectionViewStyle: CommonSectionViewStyle {
    @ViewBuilder
    private var _makeBody: @MainActor @Sendable (Configuration) -> AnyView

    init<S: CommonSectionViewStyle>(style: S) {
        _makeBody = { @MainActor configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

struct CommonSectionViewStyleKey: EnvironmentKey {
    static let defaultValue = AnyCommonSectionViewStyle(
        style: DefaultCommonSectionViewStyle()
    )
}

extension EnvironmentValues {
    var airshipCommonSectionViewStyle: AnyCommonSectionViewStyle {
        get { self[CommonSectionViewStyleKey.self] }
        set { self[CommonSectionViewStyleKey.self] = newValue }
    }
}
