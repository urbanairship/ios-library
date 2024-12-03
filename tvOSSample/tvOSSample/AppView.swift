/* Copyright Urban Airship and Contributors */

import AirshipCore
import AirshipPreferenceCenter
import SwiftUI

struct AppView: View {

    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView() {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .onAppear {
                    Airship.analytics.trackScreen("home")
                }
                .tag(SampleTabs.home)

            VStack {
                Text("Messages").font(.title)
//                MessageCenterView()
//                    .messageCenterTheme(MessageCenter.shared.theme!)
            }
//            .messageCenterMessageViewStyle(CustomMessageViewStyle())
            .tabItem {
                Label("Message Center", systemImage: "tray.fill")
            }
            .tag(SampleTabs.messageCenter)
            .onAppear {
                Airship.analytics.trackScreen("message_center")
            }

            VStack {
                Text("Preferences").font(.title)
                PreferenceCenterView(
                    preferenceCenterID: MainApp.preferenceCenterID
                )
            }
            .tabItem {
                Label("Preference Center", systemImage: "person.fill")
            }
            .tag(SampleTabs.preferenceCenter)
            .onAppear {
                Airship.analytics.trackScreen("preference_center")
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .overlay(makeToastView())
    }


    @ViewBuilder
    private func makeToastView() -> some View {
        Toast(message: self.$appState.toastMessage)
            .padding()
    }
}

struct AppView_Previews: PreviewProvider {
    static var previews: some View {
        AppView()
    }
}
//
//public struct CustomMessageViewStyle: MessageViewStyle {
//    @ViewBuilder
//    @MainActor
//    public func makeBody(configuration: Configuration) -> some View {
//        VStack {
//            Text(configuration.title ?? "").font(.title)
//                .padding(.bottom)
//            MessageCenterMessageView(
//                messageID: configuration.messageID,
//                title: configuration.title,
//                dismissAction: configuration.dismissAction
//            )
//            .messageCenterMessageViewStyle(.defaultStyle)
//        }
//    }
//}
