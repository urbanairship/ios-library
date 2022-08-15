/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Contact subscription group item view
struct ContactSubscriptionGroupView: View {

    /// The item's config
    public let item: PreferenceCenterConfig.ContactSubscriptionGroup

    /// The preference state
    @ObservedObject
    public var state: PreferenceCenterState

    @Environment(\.airshipContactSubscriptionGroupStyle)
    private var style

    @Environment(\.airshipPreferenceCenterTheme)
    private var preferenceCenterTheme

    @State
    private var displayConditionsMet: Bool = true

    @ViewBuilder
    var body: some View {

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
            componentStates: componentStates)


        style.makeBody(configuration: configuration)
            .preferenceConditions(
                self.item.conditions,
                binding: self.$displayConditionsMet
            )
    }
}

public extension View {
    /// Sets the contact subscription group style
    /// - Parameters:
    ///     - style: The style
    func contactSubscriptionGroupStyle<S>(_ style: S) -> some View where S : ContactSubscriptionGroupStyle {
        self.environment(
            \.airshipContactSubscriptionGroupStyle,
             AnyContactSubscriptionGroupStyle(style: style)
        )
    }
}

/// The contaction subscription group item style config
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

    /// Component state
    public struct ComponentState {
        /// The component
        public let component: PreferenceCenterConfig.ContactSubscriptionGroup.Component

        /// The component's subscription binding
        public let isSubscribed: Binding<Bool>
    }
}

public protocol ContactSubscriptionGroupStyle {
    associatedtype Body: View
    typealias Configuration = ContactSubscriptionGroupStyleConfiguration
    func makeBody(configuration: Self.Configuration) -> Self.Body
}

public extension ContactSubscriptionGroupStyle where Self == DefaultContactSubscriptionGroupStyle {

    /// Default style
    static var defaultStyle: Self {
        return .init()
    }
}

/// The default subscription group item style
public struct DefaultContactSubscriptionGroupStyle: ContactSubscriptionGroupStyle {

    @Environment(\.airshipPreferenceCenterTheme)
    private var preferenceCenterTheme

    private static let chipLabelAppearance = PreferenceCenterTheme.TextAppearance(
        color: .primary
    )

    static let titleAppearance = PreferenceCenterTheme.TextAppearance(
        font: .headline,
        color: .primary
    )

    static let subtitleAppearance = PreferenceCenterTheme.TextAppearance(
        font: .subheadline,
        color: .primary
    )

    @ViewBuilder
    public func makeBody(configuration: Configuration) -> some View {
        let item = configuration.item
        let itemTheme = configuration.preferenceCenterTheme.contactSubscriptionGroup

        if (configuration.displayConditionsMet) {
            VStack(alignment: .leading) {
                if let title = item.display?.title {
                    Text(title)
                        .textAppearance(
                            itemTheme?.titleAppearance,
                            base: DefaultContactSubscriptionGroupStyle.titleAppearance
                        )
                }

                if let subtitle = item.display?.subtitle {
                    Text(subtitle)
                        .textAppearance(
                            itemTheme?.subtitleAppearance,
                            base: DefaultContactSubscriptionGroupStyle.subtitleAppearance
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
        let componentStates: [Configuration.ComponentState]
        let chipTheme: PreferenceCenterTheme.Chip?

        @State
        private var componentHeight: CGFloat?

        @ViewBuilder
        var body: some View {
            var dx = CGFloat.zero
            var dy = CGFloat.zero
            let hSpacing = 8.0

            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    ForEach(0..<self.componentStates.count, id: \.self) { index in
                        let state = self.componentStates[index]
                        makeComponent(state.component, isOn: state.isSubscribed)
                            .alignmentGuide(HorizontalAlignment.leading) { viewDimensions in
                                if index == 0 {
                                    dx = 0
                                    dy = 0
                                }

                                var offSet = dx
                                if (abs(offSet - viewDimensions.width) > geometry.size.width) {
                                    offSet = 0
                                    dx = 0
                                    dy -= viewDimensions.height
                                }

                                dx -= (viewDimensions.width + hSpacing)
                                return offSet
                            }
                            .alignmentGuide(VerticalAlignment.top) { viewDimensions in
                                return dy
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
        func makeComponent(_ component: PreferenceCenterConfig.ContactSubscriptionGroup.Component,
                           isOn: Binding<Bool>) -> some View {

            Button(action: {
                isOn.wrappedValue.toggle()
            }) {
                HStack(spacing: 4) {
                    ZStack {
                        if (isOn.wrappedValue) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(chipTheme?.checkColor)
                        } else {
                            Image(systemName: "circle")
                                .font(.system(size: 24))
                                .foregroundColor(chipTheme?.borderColor ?? .secondary)
                        }
                    }

                    Text(component.display?.title ?? "")
                        .textAppearance(
                            chipTheme?.labelAppearance,
                            base: DefaultContactSubscriptionGroupStyle.chipLabelAppearance
                        )
                        .padding(.trailing, 8)
                }
                .padding(2)
                .overlay(
                    RoundedRectangle(cornerRadius: 22,
                                     style: .circular)
                    .strokeBorder(self.chipTheme?.borderColor ?? .secondary, lineWidth: 1)
                )
                .frame(minHeight: 44)
            }

        }
    }

}

struct AnyContactSubscriptionGroupStyle: ContactSubscriptionGroupStyle {
    @ViewBuilder
    private var _makeBody: (Configuration) -> AnyView

    init<S: ContactSubscriptionGroupStyle>(style: S) {
        _makeBody = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

struct ContactSubscriptionGroupStyleKey: EnvironmentKey {
    static var defaultValue = AnyContactSubscriptionGroupStyle(style: .defaultStyle)
}

extension EnvironmentValues {
    var airshipContactSubscriptionGroupStyle: AnyContactSubscriptionGroupStyle {
        get { self[ContactSubscriptionGroupStyleKey.self] }
        set { self[ContactSubscriptionGroupStyleKey.self] = newValue }
    }
}
