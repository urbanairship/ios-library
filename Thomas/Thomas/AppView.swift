/* Copyright Airship and Contributors */

import AirshipCore
import SwiftUI

struct LastLayoutButtonView: View {
    @AppStorage("lastLayoutFile") var lastLayoutFile: String?

    var body: some View {
        Button(action: {
            let layouts =  Layouts.shared.layouts

            if let lastFileName = lastLayoutFile,
               let layout = layouts.first(where: { $0.fileName == lastFileName }) {
                do {
                    try Layouts.shared.openLayout(layout)
                } catch {
                    print("Error opening last layout: \(error)")
                }
            }
        }, label: {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                Text(lastLayoutFile ?? "No Recent Layout")
                    .foregroundColor(lastLayoutFile == nil ? .gray : .primary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        })
        .disabled(lastLayoutFile == nil)
    }
}

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
                    LastLayoutButtonView()
                }
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
            }
            .navigationTitle("Layout Viewer")
        }
        .tabItem {
            Label(
                "Layout Viewer",
                systemImage: "square.3.layers.3d.down.left"
            )
        }
    }

    var body: some View {
        TabView {
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
