/* Copyright Airship and Contributors */

import AirshipCore
import SwiftUI

// MARK: - AppView

struct AppView: View {
    @StateObject
    private var viewModel = LayoutViewModel()

    enum SceneRoutes: Hashable, CaseIterable {
        case embedded
        case modal
        case banner
    }

    enum InAppAutomationRoutes: Hashable, CaseIterable {
        case modal
        case banner
        case fullscreen
        case html
    }

    @State private var layoutViewerPath = NavigationPath()
    @State var errorMessage: String?
    @State var showError: Bool = false

    func open(_ layout: LayoutFile, addToRecents: Bool = true) {
        do {
            try viewModel.openLayout(layout, addToRecents: addToRecents)
        } catch {
            self.showError = true
            self.errorMessage = "Failed to open layout \(error)"
        }
    }

    private var layoutsView: some View {
        NavigationStack(path: $layoutViewerPath) {
            Form {
                Section("Recent") {
                    ForEach(viewModel.recentLayouts) { layout in
                        Button(layout.fileName) {
                           open(layout, addToRecents: false)
                        }
                    }
                }

                Section("Scenes") {
                    ForEach(SceneRoutes.allCases, id: \.self) { route in
                        switch route {
                        case .embedded:
                            NavigationLink(value: route) {
                                Label("Embedded", systemImage: "rectangle.portrait.topleft.inset.filled")
                            }
                        case .modal:
                            NavigationLink(value: route) {
                                Label("Modal", systemImage: "rectangle.portrait.center.inset.filled")
                            }
                        case .banner:
                            NavigationLink(value: route) {
                                Label("Banner", systemImage: "rectangle.portrait.topthird.inset.filled")
                            }
                        }
                    }
                }

                Section("In-App Automations") {
                    ForEach(InAppAutomationRoutes.allCases, id: \.self) { route in
                        switch route {
                        case .modal:
                            NavigationLink(value: route) {
                                Label("Modal", systemImage: "rectangle.portrait.center.inset.filled")
                            }
                        case .banner:
                            NavigationLink(value: route) {
                                Label("Banner", systemImage: "rectangle.portrait.topthird.inset.filled")
                            }
                        case .fullscreen:
                            NavigationLink(value: route) {
                                Label("Fullscreen", systemImage: "rectangle.portrait.inset.filled")
                            }
                        case .html:
                            NavigationLink(value: route) {
                                Label("HTML", systemImage: "safari.fill")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Layout Viewer")
            .navigationDestination(for: SceneRoutes.self) { route in
                switch route {
                case .embedded:
                    EmbeddedPlaygroundMenuView()
                        .navigationTitle("Embedded")
                case .modal:
                    LayoutsList(
                        layouts: viewModel.layouts(type: .sceneModal)
                    ) {
                        open($0)
                    }
                    .navigationTitle("Modals")
                case .banner:
                    LayoutsList(
                        layouts: viewModel.layouts(type: .sceneBanner)
                    ) {
                        open($0)
                    }
                    .navigationTitle("Banners")
                }
            }
            .navigationDestination(for: InAppAutomationRoutes.self) { route in
                switch route {
                case .modal:
                    LayoutsList(
                        layouts: viewModel.layouts(type: .messageModal)
                    ) {
                        open($0)
                    }
                    .navigationTitle("Modals")
                case .banner:
                    LayoutsList(
                        layouts: viewModel.layouts(type: .messageModal)
                    ) {
                        open($0)
                    }
                    .navigationTitle("Banners")
                case .fullscreen:
                    LayoutsList(
                        layouts: viewModel.layouts(type: .messageBanner)
                    ) {
                        open($0)
                    }
                    .navigationTitle("Fullscreen")
                case .html:
                    LayoutsList(
                        layouts: viewModel.layouts(type: .messageHTML)
                    ) {
                        open($0)
                    }
                    .navigationTitle("HTML")
                }
            }
            .alert(isPresented: $showError) {
                Alert(
                    title: Text("Error"),
                    message: Text(self.errorMessage ?? "error"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .tabItem {
            Label(
                "Layout Viewer",
                systemImage: "square.3.layers.3d.down.left"
            )
        }
    }
    
    var body: some View {
        layoutsView
    }
}

#Preview {
    AppView()
}

