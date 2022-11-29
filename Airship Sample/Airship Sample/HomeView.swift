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
    private func makeQuickSettings() -> some View {
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
    private func makeHeroImage() -> some View {
        Image("HomeHeroImage")
            .resizable()
            .scaledToFit()
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
    }

    @ViewBuilder
    func makeEnablePushButton() -> some View {
        // MARK: Push/Bleat Button
        Button(action: { viewModel.pushEnabled.toggle() }) {
            ZStack {
                Capsule()
                    .strokeBorder(Color.accentColor, lineWidth: 2.0)
                    .frame(height: 40, alignment: .center)
                    .padding()

                let title =
                    self.viewModel.pushEnabled ? "Disable Push" : "Enable Push"
                Text(title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
        .padding()
    }

    @ViewBuilder
    func makeCompactContent() -> some View {
        HStack {
            VStack {
                makeHeroImage()
                makeEnablePushButton()
            }
            VStack {
                makeQuickSettings()
            }
        }
    }

    @ViewBuilder
    func makeContent() -> some View {
        VStack {
            Spacer()
            makeHeroImage()
            Spacer()
            makeEnablePushButton()
            Spacer()
            makeQuickSettings()
                .padding(.horizontal)
            Spacer()
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                if self.verticalSizeClass == .compact {
                    makeCompactContent()
                } else {
                    makeContent()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationBarTitle("")
            .navigationBarHidden(true)
            .overlay(makeSettingLink(), alignment: .topTrailing)
        }
        .navigationViewStyle(.stack)
    }

    @ViewBuilder
    private func makeSettingLink() -> some View {
        #if canImport(AirshipDebug)
        NavigationLink(
            destination: AirshipDebugView(),
            tag: HomeDestination.settings,
            selection: self.$appState.homeDestination
        ) {
            Image(systemName: "gear")
                .resizable()
                .scaledToFit()
                .foregroundColor(.accentColor)
                .padding(10)
                .frame(width: 44, height: 44)
        }
        #endif
    }

    class ViewModel: ObservableObject {
        @Published
        var pushEnabled: Bool =
            Airship.push.userPushNotificationsEnabled
            && Airship.shared.privacyManager.isEnabled(.push)
        {
            didSet {
                if pushEnabled {
                    Airship.shared.privacyManager.enableFeatures(.push)
                    Airship.push.userPushNotificationsEnabled = true
                } else {
                    Airship.push.userPushNotificationsEnabled = false
                }
            }
        }

        @Published
        var channelID: String? = Airship.channel.identifier

        @Published
        var namedUserID: String? = Airship.contact.namedUserID

        private var subscriptions = Set<AnyCancellable>()

        init() {
            NotificationCenter.default
                .publisher(for: Channel.channelCreatedEvent)
                .receive(on: RunLoop.main)
                .sink { _ in
                    self.channelID = Airship.channel.identifier
                }
                .store(in: &self.subscriptions)

            NotificationCenter.default
                .publisher(for: Contact.contactChangedEvent)
                .receive(on: RunLoop.main)
                .sink { _ in
                    self.namedUserID = Airship.contact.namedUserID
                }
                .store(in: &self.subscriptions)
        }

        func copyChannel() {
            UIPasteboard.general.string = Airship.channel.identifier
        }

    }
}
