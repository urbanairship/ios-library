/* Copyright Urban Airship and Contributors */

import AirshipCore
import AirshipMessageCenter
import AirshipPreferenceCenter
import AirshipDebug
import SwiftUI

struct AppView: View {
    
    @EnvironmentObject var appState: AppState
    
    @State var shakeCount: Int = 0
    
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
            
            MessageCenterView()
//                .messageCenterTheme(
//                    try! MessageCenterTheme.fromPlist("SampleMessageCenterTheme")
//                )
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
            
            
            PreferenceCenterView(
                preferenceCenterID: MainApp.preferenceCenterID
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
            .tag(SampleTabs.preferenceCenter)


#if canImport(AirshipDebug)
            debug.tabItem {
                Label(
                    "Debug",
                    systemImage: "gear"
                )
            }
            .onAppear {
                Airship.analytics.trackScreen("debug")
            }
            .tag(SampleTabs.debug)
#endif
        }
        .onShake {
            shakeCount += 1
            
            let event = CustomEvent(name: "shake_event", value: Double(shakeCount))
            event.track()
            
            AppState.shared.toastMessage = Toast.Message(
                text: "Tracked custom event: shake_event",
                duration: 2.0
            )
        }
        .overlay(makeToastView())
    }
    
    @ViewBuilder
    private func makeToastView() -> some View {
        Toast(message: self.$appState.toastMessage)
            .padding()
    }

#if canImport(AirshipDebug)
    @ViewBuilder
    var debug: some View {
        NavigationStack {
            ZStack{
                AirshipDebugView()
            }
        }
    }
#endif
}


struct AppView_Previews: PreviewProvider {
    static var previews: some View {
        AppView()
    }
}
