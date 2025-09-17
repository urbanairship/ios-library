/* Copyright Airship and Contributors */

import Foundation
public import SwiftUI
import Combine

#if canImport(AirshipCore)
import AirshipCore
#endif

/// The main view for the Airship Preference Center. This view provides a navigation stack.
/// If you wish to provide your own navigation, see `PreferenceCenterContent`.
public struct PreferenceCenterView: View {

    @Environment(\.preferenceCenterDismissAction)
    private var dismissAction: (@MainActor @Sendable () -> Void)?

    @Environment(\.airshipPreferenceCenterTheme)
    private var theme

    @Environment(\.colorScheme)
    private var colorScheme

    private let preferenceCenterID: String

    @State private var title: String? = nil

    /// Default constructor
    /// - Parameters:
    ///     - preferenceCenterID: The preference center ID
    public init(preferenceCenterID: String) {
        self.preferenceCenterID = preferenceCenterID
    }

    @ViewBuilder
    private func makeBackButton() -> some View {
        let theme = theme.viewController?.navigationBar
        let resolvedBackButtonColor = colorScheme.airshipResolveColor(
            light: theme?.backButtonColor,
            dark: theme?.backButtonColorDark
        )

        Button(action: {
            self.dismissAction?()
        }) {
            Image(systemName: "chevron.backward")
                .scaleEffect(0.68)
                .font(Font.title.weight(.medium))
                .foregroundColor(resolvedBackButtonColor)
        }
    }

    private var navigationBarTitle: String? {
        var title: String? = self.title

        if theme.viewController?.navigationBar?.overrideConfigTitle == true {
            title = theme.viewController?.navigationBar?.title ?? title
        }

        return title
    }


    @ViewBuilder
    public var body: some View {
        let resolvedNavigationBarColor = colorScheme.airshipResolveColor(
            light: theme.viewController?.navigationBar?.backgroundColor,
            dark: theme.viewController?.navigationBar?.backgroundColorDark
        )

        NavigationStack {
            PreferenceCenterContent(
                preferenceCenterID: preferenceCenterID,
                onPhaseChange: { phase in
                    guard case .loaded(let state) = phase else { return }

                    let title = state.config.display?.title
                    if let title, title.isEmpty == false {
                        self.title = title
                    } else {
                        self.title = "ua_preference_center_title".preferenceCenterLocalizedString
                    }
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .airshipApplyIf(resolvedNavigationBarColor != nil) { view in
                let visibility: Visibility = if #available(iOS 26.0, *) {
                    .automatic
                } else {
                    .visible
                }

                view.toolbarBackground(resolvedNavigationBarColor!, for: .navigationBar)
                    .toolbarBackground(visibility, for: .navigationBar)
            }
            .toolbar {
                if self.dismissAction != nil {
                    ToolbarItem(placement: .navigationBarLeading) {
                        makeBackButton()
                    }
                }
            }
            .navigationTitle(navigationBarTitle ?? "")
        }
    }
}


private struct PreferenceCenterDismissActionKey: EnvironmentKey {
    static let defaultValue: (@MainActor @Sendable () -> Void)? = nil
}

extension EnvironmentValues {
    var preferenceCenterDismissAction: (@MainActor @Sendable () -> Void)? {
        get { self[PreferenceCenterDismissActionKey.self] }
        set { self[PreferenceCenterDismissActionKey.self] = newValue }
    }
}

public extension View {
    
    /// Sets a dismiss action on the preference center.
    /// - Parameters:
    ///     - action: The dismiss action.
    func addPreferenceCenterDismissAction(action: (@MainActor @Sendable () -> Void)?) -> some View {
        environment(\.preferenceCenterDismissAction, action)
    }
}

struct PreferenceCenterView_Previews: PreviewProvider {
    static var previews: some View {
        let config = PreferenceCenterConfig(
            identifier: "PREVIEW",
            sections: [
                .labeledSectionBreak(
                    PreferenceCenterConfig.LabeledSectionBreak(
                        id: "LabeledSectionBreak",
                        display: PreferenceCenterConfig.CommonDisplay(
                            title: "Labeled Section Break"
                        )
                    )
                ),
                .common(
                    PreferenceCenterConfig.CommonSection(
                        id: "common",
                        items: [
                            .channelSubscription(
                                PreferenceCenterConfig.ChannelSubscription(
                                    id: "ChannelSubscription",
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
                                    id: "ContactSubscription",
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
                                    id: "ContactSubscriptionGroup",
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

        PreferenceCenterContent(preferenceCenterID: "PREVIEW") {
            preferenceCenterID in
            return await .loaded(PreferenceCenterState(config: config))
        }
    }
}
