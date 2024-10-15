/* Copyright Airship and Contributors */

import Foundation
public import SwiftUI
import Combine

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Preference center view phase
public enum PreferenceCenterViewPhase: Sendable {
    /// The view is loading
    case loading
    /// The view failed to load the config
    case error(Error)
    /// The view is loaded with the state
    case loaded(PreferenceCenterState)
}

/// Preference center view
@preconcurrency @MainActor
public struct PreferenceCenterList: View {

    @StateObject
    private var loader: PreferenceCenterViewLoader =
        PreferenceCenterViewLoader()

    @State
    private var initialLoadCalled = false

    @State
    private var namedUser: String?

    @Environment(\.airshipPreferenceCenterStyle)
    private var style

    @Environment(\.airshipPreferenceCenterTheme)
    private var preferenceCenterTheme

    private let preferenceCenterID: String
    private let onLoad: (@Sendable (String) async -> PreferenceCenterViewPhase)?
    private let onPhaseChange: ((PreferenceCenterViewPhase) -> Void)?

    /// The default constructor
    /// - Parameters:
    ///   - preferenceCenterID: The preference center ID
    ///   - onLoad: An optional load block to load the view phase
    ///   - onPhaseChange: A callback when the phase changed
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
                onLoad: onLoad
            )
        }

        let configuration = PreferenceCenterViewStyleConfiguration(
            phase: phase,
            preferenceCenterTheme: self.preferenceCenterTheme,
            refresh: refresh
        )

        style.makeBody(configuration: configuration)
            .onReceive(makeNamedUserIDPublisher()) { identifier in
                if (self.namedUser != identifier) {
                    self.namedUser = identifier
                    refresh()
                }
            }
            .onReceive(self.loader.$phase) {
                self.onPhaseChange?($0)

                if !self.initialLoadCalled {
                    refresh()
                    self.initialLoadCalled = true
                }
            }
    }

    private func makeNamedUserIDPublisher() -> AnyPublisher<String?, Never> {
        guard Airship.isFlying else {
            return Just(nil).eraseToAnyPublisher()
        }

        return Airship.contact.namedUserIDPublisher
            .receive(on: RunLoop.main)
            .dropFirst()
            .eraseToAnyPublisher()
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
    private func makeBackButton() -> some View {
        Button(action: {
            self.dismissAction?()
        }) {
            Image(systemName: "chevron.backward")
                .scaleEffect(0.68)
                .font(Font.title.weight(.medium))
                .foregroundColor(Color(UINavigationBar.appearance().tintColor ?? UIColor.systemBlue))
        }
    }

    @ViewBuilder
    public var body: some View {

        let content = PreferenceCenterList(preferenceCenterID: preferenceCenterID)
            .airshipApplyIf(self.dismissAction != nil) { view in
                view.toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        makeBackButton()
                    }
                }
            }

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
            return await .loaded(PreferenceCenterState(config: config))
        }
    }
}
