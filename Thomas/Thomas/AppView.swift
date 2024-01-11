/* Copyright Urban Airship and Contributors */

import AirshipCore
import SwiftUI

struct AppView: View {

    private var leadingTab: some View {
        HomeView23Grande()
            .tabItem {
                Label(
                    "Home",
                    systemImage: "house"
                )
            }
    }

    private var trailingTab: some View {
        NavigationView {
            Form {
                Section {
                    NavigationLink {
                        EmbeddedPlaygroundMenuView()
                            .navigationTitle("Embedded")
                    } label: {
                        Label(
                            "Embedded",
                            systemImage: "rectangle.portrait.topleft.inset.filled"
                        )
                    }
                    NavigationLink {
                        LayoutsList(type: .sceneModal)
                            .navigationTitle("Modals")
                    } label: {
                        Label(
                            "Modal",
                            systemImage: "rectangle.portrait.center.inset.filled"
                        )
                    }
                    NavigationLink {
                        LayoutsList(type: .sceneBanner)
                            .navigationTitle("Banners")
                    } label: {
                        Label(
                            "Banner",
                            systemImage: "rectangle.portrait.topthird.inset.filled"
                        )
                    }
                } header: {
                    Text("Scenes")
                        .font(.headline)
                }
                Section {
                    NavigationLink {
                        LayoutsList(type: .messageModal)
                            .navigationTitle("Modal")
                    } label: {
                        Label(
                            "Modal",
                            systemImage: "rectangle.portrait.center.inset.filled"
                        )
                    }
                    NavigationLink {
                        LayoutsList(type: .messageBanner)
                            .navigationTitle("Banner")
                    } label: {
                        Label(
                            "Banner",
                            systemImage: "rectangle.portrait.topthird.inset.filled"
                        )
                    }
                    NavigationLink {
                        LayoutsList(type: .messageFullscreen)
                            .navigationTitle("Fullscreen")
                    } label: {
                        Label(
                            "Fullscreen",
                            systemImage: "rectangle.portrait.inset.filled"
                        )
                    }
                    NavigationLink {
                        LayoutsList(type: .messageHTML)
                            .navigationTitle("HTML")
                    } label: {
                        Label(
                            "HTML",
                            systemImage: "safari.fill"
                        )
                    }
                } header: {
                    Text("Messages")
                        .font(.headline)
                }
            }.navigationTitle("Layout Viewer")
        }
        .tabItem {
            Label(
                "Layout Viewer",
                systemImage: "square.3.layers.3d.down.left"
            )
        }
    }

    var body: some View {
        TabView() {
            leadingTab
            trailingTab
        }
    }
}

struct AppView_Previews: PreviewProvider {
    static var previews: some View {
        AppView()
    }
}
