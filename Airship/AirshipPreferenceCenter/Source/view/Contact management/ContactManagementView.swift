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
public struct ContactManagementSectionStyleConfiguration: Sendable {

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
public protocol ContactManagementSectionStyle: Sendable {
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


// MARK: - DEFAULT Contact Management View
/// Default contact management section style. Also styles alert views.
public struct DefaultContactManagementSectionStyle: ContactManagementSectionStyle {

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
    private let _makeBody: @Sendable (Configuration) -> AnyView

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
    static let defaultValue = AnyContactManagementSectionStyle(style: .defaultStyle)
}

extension EnvironmentValues {
    var airshipContactManagementSectionStyle: AnyContactManagementSectionStyle {
        get { self[ContactManagementSectionStyleKey.self] }
        set { self[ContactManagementSectionStyleKey.self] = newValue }
    }
}
