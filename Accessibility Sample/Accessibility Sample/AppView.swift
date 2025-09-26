/* Copyright Airship and Contributors */

import SwiftUI
import AirshipCore
import AirshipMessageCenter
import AirshipPreferenceCenter

struct AppView: View {
    @EnvironmentObject var appState: AppState

    @ViewBuilder
    private var homeTab: some View {
        HomeView()
        .tabItem {
            Label(
                "Layout Viewer",
                systemImage: "square.3.layers.3d.down.left"
            )
        }.onAppear {
            Airship.privacyManager.enableFeatures(.push)
            Airship.push.userPushNotificationsEnabled = true
            Airship.push.backgroundPushNotificationsEnabled = true
        }
        .tag(SampleTabs.home)
    }

    @ViewBuilder
    private var messageCenterTab: some View {
        MessageCenterView()
        .tabItem {
            Label(
                "Message Center",
                systemImage: "tray.fill"
            )
        }
        .badge(self.appState.unreadCount)
        .onAppear {
            Airship.analytics.trackScreen("message_center")
        }
        .tag(SampleTabs.messageCenter)
    }

    @ViewBuilder
    private var preferenceCenterTab: some View {
        PreferenceCenterView(
            preferenceCenterID: MainApp.preferenceCenterID
        )
        .tabItem {
            Label(
                "Preferences",
                systemImage: "person.fill"
            )
        }
        .onAppear {
            Airship.analytics.trackScreen("preference_center")
        }
        .tag(SampleTabs.preferenceCenter)
    }

    @ViewBuilder
    private func makeToastView() -> some View {
        Toast(message: self.$appState.toastMessage)
            .padding()
    }

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            homeTab
            messageCenterTab
            preferenceCenterTab
        }.overlay(
            makeToastView()
        )
    }
}

struct AppView_Previews: PreviewProvider {
    static var previews: some View {
        AppView()
    }
}
