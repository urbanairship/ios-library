/* Copyright Urban Airship and Contributors */

import AirshipCore
import Combine
import SwiftUI

#if canImport(ActivityKit)
import ActivityKit
#endif

struct HomeView: View {

    @StateObject
    private var viewModel: ViewModel = ViewModel()

    @Environment(\.verticalSizeClass)
    private var verticalSizeClass

    @EnvironmentObject
    private var toast: Toast

    @EnvironmentObject
    private var appRouter: AppRouter

    @ViewBuilder
    private func makeQuickSettingItem(
        title: String,
        value: String? = nil
    ) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .foregroundColor(.accentColor)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let value {
                Text(value)
                    .foregroundColor(Color.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var quickSettings: some View {
        ScrollView {
            VStack {
                Button(
                    action: {
                        self.viewModel.copyChannel()
                        self.toast.message = Toast.Message(
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
                    value: AppRouter.HomeRoute.namedUser
                ) {
                    makeQuickSettingItem(
                        title: "Named User",
                        value: self.viewModel.namedUserID ?? "Not Set"
                    )
                }

#if canImport(ActivityKit)
                Divider()

                Button(action: {
                    do {
                        try viewModel.startLiveActivity()
                        toast.message = Toast.Message(
                            text: "Live Activity started!",
                            duration: 2.0
                        )
                    } catch {
                        toast.message = Toast.Message(
                            text: "Failed to start live activity \(error)",
                            duration: 2.0
                        )
                    }
                }) {
                    makeQuickSettingItem(
                        title: "Start Live Activity",
                        value: "Tap to create delivery"
                    )
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
    private var pushButton: some View {
        Button(action: { viewModel.toggleNotifications() }) {
            if let optedIn = viewModel.notificationStatus?.isUserOptedIn {
                Text(optedIn ? "Disable Notifications" : "Enable Notifications")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
        .controlSize(.large)
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
    }

    @ViewBuilder
    private var content: some View {
        if self.verticalSizeClass == .compact {
            HStack(spacing: 16) {
                VStack(spacing: 16) {
                    hero.frame(maxHeight: .infinity)
                    pushButton
                }
                .frame(maxHeight: .infinity)
                quickSettings.frame(maxHeight: .infinity)
            }
        } else {
            VStack(spacing: 16) {
                VStack(spacing: 16) {
                    hero.frame(maxHeight: .infinity)
                    pushButton
                }
                .frame(maxHeight: .infinity)
                quickSettings.frame(maxHeight: .infinity)
            }
        }
    }

    var body: some View {
        NavigationStack(path: self.$appRouter.homePath) {
            content
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationBarTitle("")
                .navigationBarHidden(true)
                .navigationDestination(for: AppRouter.HomeRoute.self) { route in
                    switch(route) {
                    case .namedUser: NamedUserView()
                    }
                }
        }
    }

    @MainActor
    class ViewModel: ObservableObject {
        @Published
        var notificationStatus: AirshipNotificationStatus?

        @Published
        var channelID: String?

        @Published
        var namedUserID: String?

        private var task: Task<Void, Never>? = nil

        @MainActor
        init() {
            self.task = Task { [weak self] in
                await Airship.waitForReady()

                // Get initial values
                self?.namedUserID = await Airship.contact.namedUserID
                self?.notificationStatus = await Airship.push.notificationStatus
                self?.channelID = Airship.channel.identifier

                // Listen for changes
                self?.listenForChanges()
            }
        }
        private func listenForChanges() {
            // Named User changes
            Task { @MainActor [weak self] in
                for await update in Airship.contact.namedUserIDPublisher.values {
                    self?.namedUserID = update
                }
            }

            // Push notification changes
            Task { @MainActor [weak self] in
                for await update in await Airship.push.notificationStatusUpdates {
                    self?.notificationStatus = update
                }
            }

            // Channel ID changes
            Task { @MainActor [weak self] in
                for await update in Airship.channel.identifierUpdates {
                    self?.channelID = update
                }
            }
        }

        deinit {
            task?.cancel()
        }

        func copyChannel() {
            UIPasteboard.general.string = Airship.channel.identifier
        }

#if canImport(ActivityKit)
        func startLiveActivity() throws {
            let state = DeliveryAttributes.ContentState(
                stopsAway: 10
            )

            let attributes = DeliveryAttributes(
                orderNumber: generateOrderNumber()
            )

            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: .token
            )

            Airship.channel.trackLiveActivity(
                activity,
                name: attributes.orderNumber
            )
        }
#endif

        @MainActor
        func toggleNotifications() {
            if self.notificationStatus?.isUserOptedIn != true {
                Task {
                    Airship.privacyManager.enableFeatures(.push)
                    await Airship.push.enableUserPushNotifications(fallback: .systemSettings)
                }
            } else {
                Airship.push.userPushNotificationsEnabled = false
            }
        }

        private func generateOrderNumber() -> String {
            var number = "#"
            for _ in 1...6 {
                number += "\(Int.random(in: 1...9))"
            }
            return number
        }
    }
}
