/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Preference center view phase
public enum PreferenceCenterViewPhase {
    /// The view is loading
    case loading
    /// The view failed to load the config
    case error(Error)
    /// The view is loaded with the state
    case loaded(PreferenceCenterState)
}

/// Preference center view
public struct PreferenceCenterList: View {

    @StateObject
    private var loader: PreferenceCenterViewLoader =
        PreferenceCenterViewLoader()

    @State
    private var initialLoadCalled = false

    @Environment(\.airshipPreferenceCenterStyle)
    private var style

    @Environment(\.airshipPreferenceCenterTheme)
    private var preferenceCenterTheme

    private let preferenceCenterID: String
    private let onLoad: (@Sendable (String) async -> PreferenceCenterViewPhase)?
    private let onPhaseChange: ((PreferenceCenterViewPhase) -> Void)?

    /// The default constructor
    /// - Parameters:
    ///     - preferenceCenterID: The preference center ID
    ///     - onLoad: An optional load block to load the view phase
    ///     - onPhaseChange: A callback when the phase changed
    public init(
        preferenceCenterID: String,
        onLoad: (@Sendable (String) async -> PreferenceCenterViewPhase)? = nil,
        onPhaseChange: ((PreferenceCenterViewPhase) -> Void)? = nil
    ) {
        self.preferenceCenterID = preferenceCenterID
        self.onLoad = onLoad
        self.onPhaseChange = onPhaseChange
    }

    @ViewBuilder
    public var body: some View {
        let phase = self.loader.phase

        let refresh = {
            self.loader.load(
                preferenceCenterID: preferenceCenterID,
                onLoad: self.onLoad
            )
        }

        let configuration = PreferenceCenterViewStyleConfiguration(
            phase: phase,
            preferenceCenterTheme: self.preferenceCenterTheme,
            refresh: refresh
        )

        style.makeBody(configuration: configuration)
            .onReceive(self.loader.$phase) {
                self.onPhaseChange?($0)

                if !self.initialLoadCalled {
                    refresh()
                    self.initialLoadCalled = true
                }
            }
    }
}

/// Preference Center view style configuration
public struct PreferenceCenterViewStyleConfiguration {
    /// The view's phase
    public let phase: PreferenceCenterViewPhase

    /// The preference center theme
    public let preferenceCenterTheme: PreferenceCenterTheme

    /// A block that can be called to refresh the view
    public let refresh: () -> Void
}

/// Preference Center view style
public protocol PreferenceCenterViewStyle {
    associatedtype Body: View
    typealias Configuration = PreferenceCenterViewStyleConfiguration
    func makeBody(configuration: Self.Configuration) -> Self.Body
}

extension PreferenceCenterViewStyle
where Self == DefaultPreferenceCenterViewStyle {
    /// Default style
    public static var defaultStyle: Self {
        return .init()
    }
}

/// The default Preference Center view style
public struct DefaultPreferenceCenterViewStyle: PreferenceCenterViewStyle {

    static let subtitleAppearance = PreferenceCenterTheme.TextAppearance(
        font: .subheadline
    )

    static let buttonLabelAppearance = PreferenceCenterTheme.TextAppearance(
        color: .white
    )

    @ViewBuilder
    private func makeProgressView(configuration: Configuration) -> some View {
        let title = configuration.preferenceCenterTheme.viewController?
            .navigationBar?
            .title
        ProgressView()
            .frame(alignment: .center)
            .navigationTitle(title ?? "ua_preference_center_title".preferenceCenterlocalizedString)
    }

    @ViewBuilder
    public func makeErrorView(configuration: Configuration) -> some View {
        let theme = configuration.preferenceCenterTheme.preferenceCenter
        let title = configuration.preferenceCenterTheme.viewController?
            .navigationBar?
            .title

        let retry = theme?.retryButtonLabel ?? "ua_retry_button".preferenceCenterlocalizedString
        let errorMessage =
            theme?.retryMessage ?? "ua_preference_center_empty".preferenceCenterlocalizedString

        VStack {
            Text(errorMessage)
                .textAppearance(theme?.retryMessageAppearance)
                .padding(16)

            Button(
                action: {
                    configuration.refresh()
                },
                label: {
                    Text(retry)
                        .textAppearance(
                            theme?.retryButtonLabelAppearance,
                            base: DefaultPreferenceCenterViewStyle
                                .buttonLabelAppearance
                        )
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(
                                    theme?.retryButtonBackgroundColor
                                        ?? Color.blue
                                )
                        )
                        .cornerRadius(8)
                        .frame(minWidth: 44)
                }
            )
        }
        .navigationTitle(title ?? "ua_preference_center_title".preferenceCenterlocalizedString)
    }

    public func makePreferenceCenterView(
        configuration: Configuration,
        state: PreferenceCenterState
    ) -> some View {
        let theme = configuration.preferenceCenterTheme
        var title = state.config.display?.title
        if title?.isEmpty != false {
            title =
                configuration.preferenceCenterTheme.viewController?
                .navigationBar?
                .title
        }

        return ScrollView {
            LazyVStack(alignment: .leading) {
                if let subtitle = state.config.display?.subtitle {
                    Text(subtitle)
                        .textAppearance(
                            theme.preferenceCenter?.subtitleAppearance,
                            base: DefaultPreferenceCenterViewStyle
                                .subtitleAppearance
                        )
                        .padding(.bottom, 16)
                }

                ForEach(0..<state.config.sections.count, id: \.self) { index in
                    self.section(state.config.sections[index], state: state)
                }
            }
            .padding(16)
            Spacer()
        }
    }

    @ViewBuilder
    public func makeBody(configuration: Configuration) -> some View {

        switch configuration.phase {
        case .loading:
            makeProgressView(configuration: configuration)
        case .error(_):
            makeErrorView(configuration: configuration)
        case .loaded(let state):
            makePreferenceCenterView(configuration: configuration, state: state)
        }
    }

    @ViewBuilder
    func section(
        _ section: PreferenceCenterConfig.Section,
        state: PreferenceCenterState
    ) -> some View {
        switch section {
        case .common(let section):
            CommonSectionView(section: section, state: state)
        case .labeledSectionBreak(let section):
            LabeledSectionBreakView(section: section, state: state)
        }
    }
}

struct AnyPreferenceCenterViewStyle: PreferenceCenterViewStyle {
    @ViewBuilder
    private var _makeBody: (Configuration) -> AnyView

    init<S: PreferenceCenterViewStyle>(style: S) {
        _makeBody = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

struct PreferenceCenterViewStyleKey: EnvironmentKey {
    static var defaultValue = AnyPreferenceCenterViewStyle(style: .defaultStyle)
}

extension EnvironmentValues {
    var airshipPreferenceCenterStyle: AnyPreferenceCenterViewStyle {
        get { self[PreferenceCenterViewStyleKey.self] }
        set { self[PreferenceCenterViewStyleKey.self] = newValue }
    }
}

struct PreferenceCenterView_Previews: PreviewProvider {
    static var previews: some View {
        let config = PreferenceCenterConfig(
            identifier: "PREVIEW",
            sections: [
                .labeledSectionBreak(
                    PreferenceCenterConfig.LabeledSectionBreak(
                        identifier: "LabeledSectionBreak",
                        display: PreferenceCenterConfig.CommonDisplay(
                            title: "Labeled Section Break"
                        )
                    )
                ),
                .common(
                    PreferenceCenterConfig.CommonSection(
                        identifier: "common",
                        items: [
                            .channelSubscription(
                                PreferenceCenterConfig.ChannelSubscription(
                                    identifier: "ChannelSubscription",
                                    subscriptionID: "ChannelSubscription",
                                    display:
                                        PreferenceCenterConfig.CommonDisplay(
                                            title: "Channel Subscription Title",
                                            subtitle:
                                                "Channel Subscription Subtitle"
                                        )
                                )
                            ),
                            .contactSubscription(
                                PreferenceCenterConfig.ContactSubscription(
                                    identifier: "ContactSubscription",
                                    subscriptionID: "ContactSubscription",
                                    scopes: [.app, .web],
                                    display:
                                        PreferenceCenterConfig.CommonDisplay(
                                            title: "Contact Subscription Title",
                                            subtitle:
                                                "Contact Subscription Subtitle"
                                        )
                                )
                            ),
                            .contactSubscriptionGroup(
                                PreferenceCenterConfig.ContactSubscriptionGroup(
                                    identifier: "ContactSubscriptionGroup",
                                    subscriptionID: "ContactSubscriptionGroup",
                                    components: [
                                        PreferenceCenterConfig
                                            .ContactSubscriptionGroup.Component(
                                                scopes: [.web, .app],
                                                display:
                                                    PreferenceCenterConfig
                                                    .CommonDisplay(
                                                        title:
                                                            "Web and App Component"
                                                    )
                                            )
                                    ],
                                    display:
                                        PreferenceCenterConfig.CommonDisplay(
                                            title:
                                                "Contact Subscription Group Title",
                                            subtitle:
                                                "Contact Subscription Group Subtitle"
                                        )
                                )
                            ),
                        ],
                        display: PreferenceCenterConfig.CommonDisplay(
                            title: "Section Title",
                            subtitle: "Section Subtitle"
                        )
                    )
                ),
            ]
        )

        PreferenceCenterList(preferenceCenterID: "PREVIEW") {
            preferenceCenterID in
            return .loaded(PreferenceCenterState(config: config))
        }
    }
}

/// Preference Center View
public struct PreferenceCenterView: View {

    @Environment(\.preferenceCenterDismissAction)
    private var dismissAction: (() -> Void)?

    @Environment(\.airshipPreferenceCenterTheme)
    private var theme
    
    private let preferenceCenterID: String

    /// Default constructor
    /// - Parameters:
    ///     - preferenceCenterID: The preference center ID
    public init(preferenceCenterID: String) {
        self.preferenceCenterID = preferenceCenterID
    }
    
    @ViewBuilder
    private func makeBackButton(_ theme: PreferenceCenterTheme) -> some View {
        Button(action: {
            self.dismissAction?()
        }) {
            let backImage = Image(systemName: "chevron.backward")
                .scaleEffect(0.68)
                .font(Font.title.weight(.medium))
            if let backgroundColor = theme.viewController?.navigationBar?.backgroundColor {
                backImage
                    .foregroundColor(Color(backgroundColor))
            } else {
                backImage
            }
        }
    }

    @ViewBuilder
    public var body: some View {
            
        let content = PreferenceCenterList(preferenceCenterID: preferenceCenterID)
            .airshipApplyIf(self.dismissAction != nil) { view in
                view.toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        makeBackButton(theme)
                    }
                }
            }
            .navigationTitle(
                theme.viewController?.navigationBar?.title ?? "ua_preference_center_title".preferenceCenterlocalizedString
            )
        if #available(iOS 16.0, *) {
            NavigationStack {
                ZStack{
                    content
                }
            }
        } else {
            NavigationView {
                content
            }
            .navigationViewStyle(.stack)
        }
    }
}



private struct PreferenceCenterDismissActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}


extension EnvironmentValues {
    var preferenceCenterDismissAction: (() -> Void)? {
        get { self[PreferenceCenterDismissActionKey.self] }
        set { self[PreferenceCenterDismissActionKey.self] = newValue }
    }
}


extension View {
    func addPreferenceCenterDismissAction(action: (() -> Void)?) -> some View {
        environment(\.preferenceCenterDismissAction, action)
    }
    
    @ViewBuilder
    func airshipApplyIf<Content: View>(
        _ predicate: @autoclosure () -> Bool,
        transform: (Self) -> Content
    ) -> some View {
        if predicate() {
            transform(self)
        } else {
            self
        }
    }
}
