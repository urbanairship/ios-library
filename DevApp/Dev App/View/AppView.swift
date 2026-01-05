/* Copyright Airship and Contributors */

import AirshipCore
import AirshipMessageCenter
import AirshipPreferenceCenter
import SwiftUI

struct AppView: View {
    
    @EnvironmentObject
    private var toast: Toast

    @EnvironmentObject
    private var router: AppRouter

    @StateObject
    private var viewModel: ViewModel = ViewModel()

    var body: some View {
        TabView(selection: $router.selectedTab) {
            HomeView()
                .tabItem {
                    Label(
                        "Home",
                        systemImage: "house.fill"
                    )
                }
                .onAppear {
                    Airship.analytics.trackScreen("home")
                }
                .tag(AppRouter.Tabs.home)

            MessageCenterView(
                controller: router.messageCenterController
            )
            .tabItem {
                Label(
                    "Message Center",
                    systemImage: "tray.fill"
                )
            }
            #if !os(tvOS)
                .badge(self.viewModel.messageCenterUnreadcount)
            #endif
                .onAppear {
                    Airship.analytics.trackScreen("message_center")
                }
                .tag(AppRouter.Tabs.messageCenter)

            PreferenceCenterView(
                preferenceCenterID: router.preferenceCenterID
            )
            .navigationViewStyle(.stack)
            .tabItem {
                Label(
                    "Preferences",
                    systemImage: "person.fill"
                )
            }
            .onAppear {
                Airship.analytics.trackScreen("preference_center")
            }
            .tag(AppRouter.Tabs.preferenceCenter)
        }
        .overlay {
            ToastView(toast: toast).padding()
        }
    }

    @MainActor
    final class ViewModel: ObservableObject {

        @Published
        var messageCenterUnreadcount: Int

        private var task: Task<Void, Never>? = nil

        @MainActor
        init() {
            self.messageCenterUnreadcount = 0
            self.task = Task { [weak self] in
                await Airship.waitForReady()
                for await unreadCount in Airship.messageCenter.inbox.unreadCountUpdates {
                    self?.messageCenterUnreadcount = unreadCount
                }
            }
        }

        deinit {
            task?.cancel()
        }
    }
}

#Preview {
    AppView()
        .environmentObject(AppRouter())
        .environmentObject(Toast())
}
