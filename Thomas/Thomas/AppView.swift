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
                        systemImage: "rectangle.inset.filled"
                    )
                }
            
            NavigationView {
                LayoutsList(type: .modal)
                    .navigationTitle("Modals")
            }
            .tabItem {
                Label(
                    "Modals",
                    systemImage: "rectangle.center.inset.filled"
                )
            }
            NavigationView {
                LayoutsList(type: .banner)
                    .navigationTitle("Banners")

            }
            .tabItem {
                Label(
                    "Banners",
                    systemImage: "rectangle.topthird.inset.filled"
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
