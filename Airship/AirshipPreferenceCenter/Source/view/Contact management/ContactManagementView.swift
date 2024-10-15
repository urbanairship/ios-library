/* Copyright Airship and Contributors */

public import SwiftUI
import Combine

#if canImport(AirshipCore)
import AirshipCore
#endif

public struct PreferenceCenterContactManagementView: View {

    /// The item's config
    public let item: PreferenceCenterConfig.ContactManagementItem

    /// The preference state
    @ObservedObject
    public var state: PreferenceCenterState

    @Environment(\.airshipContactManagementSectionStyle)
    private var style

    @Environment(\.airshipPreferenceCenterTheme)
    private var theme: PreferenceCenterTheme
    
    @State
    private var displayConditionsMet: Bool = true
    
    public init(
        item: PreferenceCenterConfig.ContactManagementItem,
        state: PreferenceCenterState
    ) {
        self.item = item
        self.state = state
    }

    @ViewBuilder
    public var body: some View {
        let configuration = ContactManagementSectionStyleConfiguration(
            section: self.item,
            state: self.state,
            displayConditionsMet: self.displayConditionsMet,
            preferenceCenterTheme: self.theme
        )

        style.makeBody(configuration: configuration)
            .preferenceConditions(
                self.item.conditions,
                binding: self.$displayConditionsMet
            )
    }
}

/// The labeled section break style configuration
public struct ContactManagementSectionStyleConfiguration {

    /// The section config
    public let section: PreferenceCenterConfig.ContactManagementItem

    /// The preference state
    public let state: PreferenceCenterState
    
    /// If the display conditions are met for this item
    public let displayConditionsMet: Bool
    
    /// The preference center theme
    public let preferenceCenterTheme: PreferenceCenterTheme
}


extension View {
    /// Sets the contact management section style
    /// - Parameters:
    ///     - style: The style
    public func ContactManagementSectionStyle<S>(_ style: S) -> some View
    where S: ContactManagementSectionStyle {
        self.environment(
            \.airshipContactManagementSectionStyle,
             AnyContactManagementSectionStyle(style: style)
        )
    }
}

/// Contact management section style
public protocol ContactManagementSectionStyle {
    associatedtype Body: View
    typealias Configuration = ContactManagementSectionStyleConfiguration
    func makeBody(configuration: Self.Configuration) -> Self.Body
}

extension ContactManagementSectionStyle
where Self == DefaultContactManagementSectionStyle {

    /// Default style
    public static var defaultStyle: Self {
        return .init()
    }
}

internal struct DefaultColors {
    static let primaryText: Color = Color(UIColor { (traitCollection: UITraitCollection) -> UIColor in
        return traitCollection.userInterfaceStyle == .dark ? UIColor.white : AirshipColorUtils.color("#333333") ?? UIColor.label
    })

    static let primaryInvertedText: Color = Color(UIColor { (traitCollection: UITraitCollection) -> UIColor in
        return (traitCollection.userInterfaceStyle == .dark ? AirshipColorUtils.color("#333333") : UIColor.white) ?? UIColor.systemBackground
    })

    static let secondaryText: Color = Color(UIColor { (traitCollection: UITraitCollection) -> UIColor in
        return (traitCollection.userInterfaceStyle == .dark ? UIColor.white : AirshipColorUtils.color("#666666")) ?? UIColor.secondaryLabel
    })

    static let secondaryBackground: Color = Color(UIColor { (traitCollection: UITraitCollection) -> UIColor in
        return (traitCollection.userInterfaceStyle == .dark ? AirshipColorUtils.color("#272727") : UIColor.secondarySystemBackground) ?? UIColor.secondarySystemBackground
    })

    static let linkBlue: Color = Color(UIColor { (traitCollection: UITraitCollection) -> UIColor in
        return (traitCollection.userInterfaceStyle == .dark ? AirshipColorUtils.color("#619AFF") : AirshipColorUtils.color("#316BF2")) ?? UIColor.secondaryLabel
    })

    static let alertRed: Color = Color(UIColor { (traitCollection: UITraitCollection) -> UIColor in
        return (traitCollection.userInterfaceStyle == .dark ? AirshipColorUtils.color("#FF677F") : AirshipColorUtils.color("#E6193B")) ?? UIColor.red
    })

    static let destructiveRed: Color = Color(UIColor { (traitCollection: UITraitCollection) -> UIColor in
        return (traitCollection.userInterfaceStyle == .dark ? AirshipColorUtils.color("#B20D25") : AirshipColorUtils.color("#B9142B")) ?? UIColor.red
    })
}

// MARK: - DEFAULT Contact Management View
/// Default contact management section style. Also styles alert views.
public struct DefaultContactManagementSectionStyle: ContactManagementSectionStyle {
    static let backgroundColor = DefaultColors.secondaryBackground

    static let titleAppearance = PreferenceCenterTheme.TextAppearance(
        font: .headline,
        color: DefaultColors.primaryText
    )

    static let subtitleAppearance = PreferenceCenterTheme.TextAppearance(
        font: .subheadline,
        color: DefaultColors.primaryText
    )

    static let resendButtonTitleAppearance = PreferenceCenterTheme.TextAppearance(
        font: .caption.weight(.bold),
        color: DefaultColors.linkBlue
    )

    static let listTitleAppearance = PreferenceCenterTheme.TextAppearance(
        font: .callout.weight(.regular),
        color: DefaultColors.secondaryText
    )

    static let listSubtitleAppearance = PreferenceCenterTheme.TextAppearance(
        font: .caption.weight(.regular),
        color: DefaultColors.secondaryText
    )

    static let errorAppearance = PreferenceCenterTheme.TextAppearance(
        font: .footnote.weight(.medium),
        color: DefaultColors.alertRed
    )

    static let buttonLabelAppearance = PreferenceCenterTheme.TextAppearance(
        font: .headline.weight(.bold),
        color: DefaultColors.primaryInvertedText
    )

    static let buttonLabelDestructiveAppearance = PreferenceCenterTheme.TextAppearance(
        font: .headline.weight(.bold),
        color: .white
    )

    static let buttonLabelOutlineAppearance = PreferenceCenterTheme.TextAppearance(
        font: .headline.weight(.bold),
        color: DefaultColors.primaryText
    )

    static let buttonBackgroundColor = DefaultColors.primaryText
    static let buttonDestructiveBackgroundColor = DefaultColors.destructiveRed

    @ViewBuilder
    public func makeBody(configuration: Configuration) -> some View {
        if configuration.displayConditionsMet {
            DefaultContactManagementView(configuration: configuration)
        }
    }
}

private struct DefaultContactManagementView: View {

    /// The item's config
    public let configuration: ContactManagementSectionStyleConfiguration

    var body: some View {
        ChannelListView(
            item: configuration.section,
            state: configuration.state
        )
        .transition(.opacity)
    }
}

struct AnyContactManagementSectionStyle: ContactManagementSectionStyle {
    @ViewBuilder
    private var _makeBody: (Configuration) -> AnyView

    init<S: ContactManagementSectionStyle>(style: S) {
        _makeBody = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

struct ContactManagementSectionStyleKey: EnvironmentKey {
    static var defaultValue = AnyContactManagementSectionStyle(style: .defaultStyle)
}

extension EnvironmentValues {
    var airshipContactManagementSectionStyle: AnyContactManagementSectionStyle {
        get { self[ContactManagementSectionStyleKey.self] }
        set { self[ContactManagementSectionStyleKey.self] = newValue }
    }
}
