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

    private var validatorDelegate: PreferenceCenterValidatorDelegate?
    
    @Environment(\.airshipCommonSectionViewStyle)
    private var style

    @Environment(\.airshipPreferenceCenterTheme)
    private var preferenceCenterTheme

    @State
    private var displayConditionsMet: Bool = true

    init(
        section: PreferenceCenterConfig.CommonSection,
        state: PreferenceCenterState,
        validatorDelegate: PreferenceCenterValidatorDelegate? = nil
    ) {
        self.section = section
        self.state = state
        self.validatorDelegate = validatorDelegate
    }
    
    @ViewBuilder
    public var body: some View {
        let configuration = CommonSectionViewStyleConfiguration(
            section: self.section, 
            validatorDelegate: self.validatorDelegate,
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

    /// The validator delegate
    public let validatorDelegate: PreferenceCenterValidatorDelegate?
    
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

/// The default common section view style
public struct DefaultCommonSectionViewStyle: CommonSectionViewStyle {

    public static let titleAppearance = PreferenceCenterTheme.TextAppearance(
        font: .system(size: 18).bold(),
        color: .primary
    )

    public static let subtitleAppearance = PreferenceCenterTheme.TextAppearance(
        font: .system(size: 14),
        color: .secondary
    )

    public static let emptyTextAppearance = PreferenceCenterTheme.TextAppearance(
        font: .system(size: 14),
        color: .gray.opacity(0.80)
    )

    @ViewBuilder
    public func makeBody(configuration: Configuration) -> some View {
        let section = configuration.section
        let sectionTheme = configuration.preferenceCenterTheme.commonSection
        let validatorDelegate = configuration.validatorDelegate

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
                    makeItem(
                        section.items[index],
                        state: configuration.state,
                        validatorDelegate: validatorDelegate
                    )
                }
            }
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    func makeItem(
        _ item: PreferenceCenterConfig.Item,
        state: PreferenceCenterState,
        validatorDelegate: PreferenceCenterValidatorDelegate?
    ) -> some View {
        switch item {
        case .alert(let item):
            PreferenceCenterAlertView(item: item, state: state).transition(.opacity)
        case .channelSubscription(let item):
            ChannelSubscriptionView(item: item, state: state)
            Divider()
        case .contactSubscription(let item):
            ContactSubscriptionView(item: item, state: state)
            Divider()
        case .contactSubscriptionGroup(let item):
            ContactSubscriptionGroupView(item: item, state: state)
            Divider()
        case .contactManagement(let item):
            PreferenceCenterContactManagementView(
                item: item,
                state: state,
                validatorDelegate: validatorDelegate
            )
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
