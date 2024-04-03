/* Copyright Airship and Contributors */

import SwiftUI
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

// MARK: DEFAULT Contact Management View
/// Default  contact management section style
public struct DefaultContactManagementSectionStyle: ContactManagementSectionStyle {
    
    static let backgroundColor = Color.white
    
    static let titleAppearance = PreferenceCenterTheme.TextAppearance(
        font: .headline,
        color: .primary
    )
    
    static let subtitleAppearance = PreferenceCenterTheme.TextAppearance(
        font: .subheadline,
        color: .primary
    )
    
    static let defaultErrorAppearance = PreferenceCenterTheme.TextAppearance(
        color: .red
    )
    static let buttonLabelAppearance = PreferenceCenterTheme.TextAppearance(
        color: .white
    )
    
    static let buttonBackgroundColor = Color.blue
    
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
        ChannelsListView(
            item: configuration.section,
            state: configuration.state
        )
        .transition(.scale)
    }
}

// MARK: LabeledButton
public struct LabeledButton: View {
    
    public var item: PreferenceCenterConfig.ContactManagementItem.LabeledButton
    public var enabled: Binding<Bool>?
    var theme: PreferenceCenterTheme.ContactManagement?
    public var action: (()->())?
    
    public init(
        item: PreferenceCenterConfig.ContactManagementItem.LabeledButton,
        enabled: Binding<Bool>? = nil,
        theme: PreferenceCenterTheme.ContactManagement?,
        action: (() -> ())?
    ) {
        self.item = item
        self.enabled = enabled
        self.theme = theme
        self.action = action
    }
    
    var isDisabled: Bool {
        if let enabled = self.enabled {
            return !enabled.wrappedValue
        }
        return false
    }
    
    var activeBackgroundColor: Color {
        return theme?.buttonBackgroundColor ?? DefaultContactManagementSectionStyle.buttonBackgroundColor
    }
    
    public var body: some View {
        VStack {
            Button {
                if let action = action {
                    action()
                }
            } label: {
                Text(self.item.text)
                    .textAppearance(
                        theme?.buttonLabelAppearance,
                        base: DefaultContactManagementSectionStyle.buttonLabelAppearance
                    )
            }
            .padding(EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10))
            .background(isDisabled ? .gray : activeBackgroundColor)
            .cornerRadius(3)
            .disabled(isDisabled)
            .optAccessibilityLabel(
                string: self.item.contentDescription
            )
            
        }
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
