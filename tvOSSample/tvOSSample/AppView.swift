/* Copyright Urban Airship and Contributors */

import AirshipCore
import AirshipPreferenceCenter
import SwiftUI
import AirshipDebug

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
                Text("Preferences").font(.title)
                PreferenceCenterView(
                    preferenceCenterID: MainApp.preferenceCenterID
                )
            }
            .tabItem {
                Label("Preference Center", systemImage: "person.fill")
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
        .tabViewStyle(.sidebarAdaptable)
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
        if #available(iOS 16.0, *) {
            NavigationStack {
                ZStack{
                    AirshipDebugView()
                }
            }
        } else {
            NavigationView {
                AirshipDebugView()
            }
            .navigationViewStyle(.stack)
        }
    }
#endif
    
}

#Preview {
    AppView()
        .environmentObject(AppState.shared)
}
