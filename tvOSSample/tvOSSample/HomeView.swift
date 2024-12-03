/* Copyright Urban Airship and Contributors */

import AirshipCore
import Combine
import SwiftUI

struct HomeView: View {

    enum Path: Sendable, Hashable, Equatable, CaseIterable {
        case namedUser
    }

    @State private var path: [Path] = []

    @StateObject
    private var viewModel: ViewModel = ViewModel()

    @EnvironmentObject
    private var appState: AppState

    @ViewBuilder
    private func makeQuickSettingItem(title: String, value: String) -> some View
    {
        VStack(alignment: .leading) {
            Text(title)
                .foregroundColor(.accentColor)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(value)
                .foregroundColor(Color.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var hero: some View {
//        AirshipEmbeddedView(embeddedID: "test") {
            VStack {
                Image("HomeHeroImage")
                    .resizable()
                    .scaledToFit()

                Text("Channel ID: \(self.viewModel.channelID ?? "Unavailable")")
                    .font(.subheadline)
            }
//        }
    }

    @ViewBuilder
    private var enablePushButton: some View {
        Toggle("Push Notifications", isOn: self.$viewModel.pushEnabled)
    }

    @ViewBuilder
    private var namedUserButton: some View {
        Button(action: {
            self.path.append(.namedUser)
        }) {
            makeQuickSettingItem(
                title: "Named User",
                value: self.viewModel.namedUserID ?? "Not Set"
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        GeometryReader { proxy in
            VStack {
                HStack() {
                    VStack {
                        hero
                    }
                    .frame(maxHeight: .infinity)
                    .focusSection()

                    Spacer()

                    VStack() {
                        enablePushButton
                            .padding(.bottom)
                        namedUserButton
                            .padding(.bottom)
                    }
                    .frame(maxHeight: .infinity)
                    .focusSection()

                }
            }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            content.padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationBarTitle("Home")
                .navigationDestination(for: Path.self) { selection in
                    switch(selection) {
                    case .namedUser:
                        NamedUserView()
                    }
                }
        }
    }

    @MainActor
    class ViewModel: ObservableObject {
        @Published
        var pushEnabled: Bool = true {
            didSet {
                if (pushEnabled) {
                    Task {
                        await Airship.push.enableUserPushNotifications(fallback: .systemSettings)
                    }
                } else {
                    Airship.push.userPushNotificationsEnabled = false
                }
            }
        }

        @Published
        var channelID: String? = Airship.channel.identifier

        @Published
        var namedUserID: String? = ""

        private var subscriptions = Set<AnyCancellable>()

        @MainActor
        init() {
            NotificationCenter.default
                .publisher(for: AirshipNotifications.ChannelCreated.name)
                .receive(on: RunLoop.main)
                .sink { _ in
                    self.channelID = Airship.channel.identifier
                }
                .store(in: &self.subscriptions)

            Airship.contact.namedUserIDPublisher
                .receive(on: RunLoop.main)
                .sink { namedUserID in
                    self.namedUserID = namedUserID
                }
                .store(in: &self.subscriptions)

            Airship.push.notificationStatusPublisher
                .map { status in
                    status.isUserOptedIn
                }
                .receive(on: RunLoop.main)
                .sink { optedIn in
                    if (self.pushEnabled != optedIn) {
                        self.pushEnabled = optedIn
                    }
                }
                .store(in: &self.subscriptions)
        }
    }
}
