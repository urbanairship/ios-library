/* Copyright Urban Airship and Contributors */

import SwiftUI
import AirshipCore
import AirshipPreferenceCenter
import AirshipMessageCenter

struct AppView: View {

    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {

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
                .tag(SampleTabs.home)

            MessageCenterView(
                controller: self.appState.messageCenterController
            )
            .tabItem {
                Label(
                    "Message Center",
                    systemImage: "tray.fill"
                )
            }
            .badgeCompat(self.appState.unreadCount)
            .onAppear {
                Airship.analytics.trackScreen("message_center")
            }
            .tag(SampleTabs.messageCenter)

            NavigationView {
                PreferenceCenterView(
                    preferenceCenterID: MainApp.preferenceCenterID
                )
            }
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
            .tag(SampleTabs.preferenceCenter)
        }
        .overlay(makeToastView())
    }

    @ViewBuilder
    private func makeToastView() -> some View {
        Toast(message: self.$appState.toastMessage)
            .padding()
    }
}


extension View {
    @ViewBuilder
    func badgeCompat(_ badge: Int) -> some View {
        if #available(iOS 15.0, *) {
            self.badge(badge)
        } else {
            self
        }
    }
}

struct AppView_Previews: PreviewProvider {
    static var previews: some View {
        AppView()
    }
}

