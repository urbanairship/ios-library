/* Copyright Urban Airship and Contributors */

import AirshipCore
import Combine
import SwiftUI

#if canImport(AirshipDebug)
import AirshipDebug
#endif

struct HomeView: View {

    @StateObject
    private var viewModel: ViewModel = ViewModel()


    @Environment(\.verticalSizeClass)
    private var verticalSizeClass

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
    private var quickSettings: some View {
        ScrollView {
            VStack {
                Button(
                    action: {
                        self.viewModel.copyChannel()
                        self.appState.toastMessage = Toast.Message(
                            text: "Channel copied to pasteboard",
                            duration: 2.0
                        )
                    }
                ) {
                    makeQuickSettingItem(
                        title: "Channel ID",
                        value: self.viewModel.channelID ?? "Unavailable"
                    )
                }

                Divider()

                NavigationLink(
                    destination: NamedUserView(),
                    tag: HomeDestination.namedUser,
                    selection: self.$appState.homeDestination
                ) {
                    makeQuickSettingItem(
                        title: "Named User",
                        value: self.viewModel.namedUserID ?? "Not Set"
                    )
                }

                Divider()

#if canImport(ActivityKit)
                if #available(iOS 16.1, *) {
                    NavigationLink(
                        destination: LiveActivityManagementView(),
                        tag: HomeDestination.liveactivities,
                        selection: self.$appState.homeDestination
                    ) {
                        Text("Live Activities!")
                            .foregroundColor(.accentColor)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
#endif
            }
        }
    }

    @ViewBuilder
    private var hero: some View {
        AirshipEmbeddedView(embeddedID: "test") {
            Image("HomeHeroImage")
                .resizable()
                .scaledToFit()
        }
    }

    @ViewBuilder
    private var enablePushButton: some View {
        // MARK: Push/Bleat Button
        Button(action: { viewModel.togglePushEnabled() }) {
            ZStack {
                Capsule()
                    .strokeBorder(Color.accentColor, lineWidth: 2.0)
                    .frame(height: 44, alignment: .center)
                let title =
                    self.viewModel.pushEnabled ? "Disable Push" : "Enable Push"
                Text(title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if self.verticalSizeClass == .compact {
            HStack(spacing: 16) {
                VStack(spacing: 16) {
                    hero.frame(maxHeight: .infinity)
                    enablePushButton
                }
                .frame(maxHeight: .infinity)
                quickSettings.frame(maxHeight: .infinity)
            }
        } else {
            VStack(spacing: 16) {
                VStack(spacing: 16) {
                    hero.frame(maxHeight: .infinity)
                    enablePushButton
                }
                .frame(maxHeight: .infinity)
                quickSettings.frame(maxHeight: .infinity)
            }
        }
    }

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    content
                }
            } else {
                NavigationView {
                    content
                }
                .navigationViewStyle(.stack)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarTitle("")
        .navigationBarHidden(true)
    }

    @MainActor
    class ViewModel: ObservableObject {
        @Published
        var pushEnabled: Bool = true

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
                    self.pushEnabled = optedIn
                }
                .store(in: &self.subscriptions)
        }

        func copyChannel() {
            UIPasteboard.general.string = Airship.channel.identifier
        }

        @MainActor
        func togglePushEnabled() {
            if (!pushEnabled) {
                Task {
                    await Airship.push.enableUserPushNotifications(fallback: .systemSettings)
                }
            } else {
                Airship.push.userPushNotificationsEnabled = false
            }
        }
    }
}
