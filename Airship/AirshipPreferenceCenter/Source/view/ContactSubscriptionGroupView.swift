/* Copyright Airship and Contributors */

import Foundation
public import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Contact subscription group item view
public struct ContactSubscriptionGroupView: View {
    /// The item's config
    public let item: PreferenceCenterConfig.ContactSubscriptionGroup

    /// The preference state
    @ObservedObject
    public var state: PreferenceCenterState

    @Environment(\.airshipContactSubscriptionGroupStyle)
    private var style

    @Environment(\.airshipPreferenceCenterTheme)
    private var preferenceCenterTheme

    @Environment(\.colorScheme)
    private var colorScheme

    @State
    private var displayConditionsMet: Bool = true
    

    public init(item: PreferenceCenterConfig.ContactSubscriptionGroup, state: PreferenceCenterState) {
        self.item = item
        self.state = state
    }

    @ViewBuilder
    public var body: some View {

        let componentStates = self.item.components
            .map {
                ContactSubscriptionGroupStyleConfiguration.ComponentState(
                    component: $0,
                    isSubscribed: self.state.makeBinding(
                        contactListID: item.subscriptionID,
                        scopes: $0.scopes
                    )
                )
            }

        let configuration = ContactSubscriptionGroupStyleConfiguration(
            item: self.item,
            state: self.state,
            displayConditionsMet: self.displayConditionsMet,
            preferenceCenterTheme: self.preferenceCenterTheme,
            componentStates: componentStates,
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
    /// Sets the contact subscription group style
    /// - Parameters:
    ///     - style: The style
    public func contactSubscriptionGroupStyle<S>(_ style: S) -> some View
    where S: ContactSubscriptionGroupStyle {
        self.environment(
            \.airshipContactSubscriptionGroupStyle,
            AnyContactSubscriptionGroupStyle(style: style)
        )
    }
}

/// The contact subscription group item style config
public struct ContactSubscriptionGroupStyleConfiguration {
    public let item: PreferenceCenterConfig.ContactSubscriptionGroup
    /// The preference state
    public let state: PreferenceCenterState

    /// If the display conditions are met for this item
    public let displayConditionsMet: Bool

    /// The preference center theme
    public let preferenceCenterTheme: PreferenceCenterTheme

    /// Component enabled states
    public let componentStates: [ComponentState]

    /// Color scheme
    public let colorScheme: ColorScheme

    /// Component state
    public struct ComponentState {
        /// The component
        public let component:
            PreferenceCenterConfig.ContactSubscriptionGroup.Component

        /// The component's subscription binding
        public let isSubscribed: Binding<Bool>
    }
}

public protocol ContactSubscriptionGroupStyle: Sendable {
    associatedtype Body: View
    typealias Configuration = ContactSubscriptionGroupStyleConfiguration
    
    @MainActor
    func makeBody(configuration: Self.Configuration) -> Self.Body
}

extension ContactSubscriptionGroupStyle
where Self == DefaultContactSubscriptionGroupStyle {

    /// Default style
    public static var defaultStyle: Self {
        return .init()
    }
}

/// The default subscription group item style
public struct DefaultContactSubscriptionGroupStyle: ContactSubscriptionGroupStyle {

    @ViewBuilder
    @MainActor
    public func makeBody(configuration: Configuration) -> some View {
        let colorScheme = configuration.colorScheme
        let item = configuration.item
        let itemTheme = configuration.preferenceCenterTheme
            .contactSubscriptionGroup

        if configuration.displayConditionsMet {
            VStack(alignment: .leading) {
                if let title = item.display?.title {
                    Text(title)
                        .textAppearance(
                            itemTheme?.titleAppearance,
                            base: PreferenceCenterDefaults.titleAppearance,
                            colorScheme: colorScheme
                        )
                        .accessibilityAddTraits(.isHeader)
                }

                if let subtitle = item.display?.subtitle {
                    Text(subtitle)
                        .textAppearance(
                            itemTheme?.subtitleAppearance,
                            base: PreferenceCenterDefaults.subtitleAppearance,
                            colorScheme: colorScheme
                        )
                }

                ComponentsView(
                    componentStates: configuration.componentStates,
                    chipTheme: itemTheme?.chip
                )
            }
        }
    }

    private struct ComponentsView: View {
        @Environment(\.colorScheme)
        private var colorScheme

        let componentStates: [Configuration.ComponentState]
        let chipTheme: PreferenceCenterTheme.Chip?

        @State
        private var componentHeight: CGFloat?

        @ViewBuilder
        var body: some View {
            let dx = AirshipAtomicValue(CGFloat.zero)
            let dy = AirshipAtomicValue(CGFloat.zero)

            let chipSpacing = PreferenceCenterDefaults.chipSpacing

            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    ForEach(0..<self.componentStates.count, id: \.self) {
                        index in
                        let state = self.componentStates[index]
                        let size = geometry.size
                        
                        makeComponent(state.component, isOn: state.isSubscribed)
                            .alignmentGuide(HorizontalAlignment.leading) {
                                viewDimensions in
                                
                                if index == 0 {
                                    dx.value = 0
                                    dy.value = 0
                                }

                                var offSet = dx.value
                                if abs(offSet - viewDimensions.width)
                                    > size.width
                                {
                                    offSet = 0
                                    dx.value = 0
                                    dy.value -= viewDimensions.height + chipSpacing
                                }

                                dx.value -= (viewDimensions.width + chipSpacing)
                                return offSet
                            }
                            .alignmentGuide(VerticalAlignment.top) {
                                viewDimensions in
                                return dy.value
                            }
                    }
                }
                .background(
                    GeometryReader(content: { contentMetrics -> Color in
                        let size = contentMetrics.size
                        DispatchQueue.main.async {
                            self.componentHeight = size.height
                        }
                        return Color.clear
                    })
                )
            }
            .frame(minHeight: componentHeight)
        }

        @ViewBuilder
        func makeComponent(
            _ component: PreferenceCenterConfig.ContactSubscriptionGroup
                .Component,
            isOn: Binding<Bool>
        ) -> some View {
            let onColor: Color = colorScheme.airshipResolveColor(light: chipTheme?.checkColor, dark: chipTheme?.checkColorDark) ?? .green
            let offColor: Color = colorScheme.airshipResolveColor(light: chipTheme?.borderColor, dark: chipTheme?.borderColorDark) ?? .secondary
            let borderColor: Color = colorScheme.airshipResolveColor(light: chipTheme?.borderColor, dark: chipTheme?.borderColorDark) ?? .secondary

            Toggle(isOn: isOn) {
                Text(component.display?.title ?? "")
            }.toggleStyle(
                ChipToggleStyle(onColor: onColor, offColor: offColor, borderColor: borderColor)
            )
#if !os(tvOS)
            .controlSize(.regular)
#endif
            .textAppearance(
                chipTheme?.labelAppearance,
                base: PreferenceCenterDefaults.chipLabelAppearance,
                colorScheme: colorScheme
            )
        }
    }
}

struct AnyContactSubscriptionGroupStyle: ContactSubscriptionGroupStyle {
    @ViewBuilder
    private let _makeBody: @MainActor @Sendable (Configuration) -> AnyView

    init<S: ContactSubscriptionGroupStyle>(style: S) {
        _makeBody = { @MainActor configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

struct ContactSubscriptionGroupStyleKey: EnvironmentKey {
    static let defaultValue = AnyContactSubscriptionGroupStyle(
        style: .defaultStyle
    )
}

extension EnvironmentValues {
    var airshipContactSubscriptionGroupStyle: AnyContactSubscriptionGroupStyle {
        get { self[ContactSubscriptionGroupStyleKey.self] }
        set { self[ContactSubscriptionGroupStyleKey.self] = newValue }
    }
}

struct ChipToggleStyle: ToggleStyle {
    // Custom colors can be passed in during initialization.
    var onColor: Color
    var offColor: Color
    var borderColor: Color

    func makeBody(configuration: Configuration) -> some View {
#if os(tvOS)
        Button(action: { configuration.isOn.toggle() }) {
            HStack(spacing: 10) {
                Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(configuration.isOn ? onColor : offColor)

                configuration.label
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.bordered)
        .tint(configuration.isOn ? onColor.opacity(0.2) : nil)
        .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
#elseif os(visionOS)
        Button(action: { configuration.isOn.toggle() }) {
            HStack {
                Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(configuration.isOn ? onColor : offColor)

                configuration.label
                    .foregroundColor(.primary)
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(configuration.isOn ? onColor.opacity(0.2) : nil)
        .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
#else
        Button(action: { configuration.isOn.toggle() }) {
            HStack {
                Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(configuration.isOn ? onColor : offColor)

                configuration.label
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.bordered)
        .tint(configuration.isOn ? onColor.opacity(0.4) : offColor.opacity(0.4))
        .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
#endif
    }
}
