/* Copyright Urban Airship and Contributors */

import AirshipCore
import SwiftUI

struct AppView: View {

    var body: some View {
        TabView() {
            HomeView23Grande()
                .tabItem {
                    Label(
                        "Embedded",
                        systemImage: "house.fill"
                    )
                }
            
            NavigationView {
                LayoutsList(type: .modal)
                    .navigationTitle("Modals")
            }
            .tabItem {
                Label(
                    "Modals",
                    systemImage: "house.fill"
                )
            }
            NavigationView {
                LayoutsList(type: .banner)
                    .navigationTitle("Banners")

            }
            .tabItem {
                Label(
                    "Banners",
                    systemImage: "house.fill"
                )
            }


        }
    }

}

struct AppView_Previews: PreviewProvider {
    static var previews: some View {
        AppView()
    }
}
