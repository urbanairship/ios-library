/* Copyright Airship and Contributors */

import AirshipCore
import SwiftUI

// MARK: - AppView

struct ThomasLayoutListView: View {
    @StateObject
    private var viewModel = ThomasLayoutViewModel()

    private enum SceneRoutes: Hashable, CaseIterable {
        case embedded
        case modal
        case banner
    }

    private enum InAppAutomationRoutes: Hashable, CaseIterable {
        case modal
        case banner
        case fullscreen
        case html
    }

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
        Form {
            Section {
                ForEach(viewModel.recentLayouts) { layout in
                    Button(layout.fileName) {
                       open(layout, addToRecents: false)
                    }
                }
            } header: {
                HStack {
                    Text("Recent")
                    Spacer()
                    Button("Clear") {
                        viewModel.clearRecentLayouts()
                    }
                    .disabled(viewModel.recentLayouts.isEmpty)
                }
            }

            Section("Scenes") {
                ForEach(SceneRoutes.allCases, id: \.self) { route in
                    switch route {
                    case .embedded:
                        NavigationLink(value: AppRouter.HomeRoute.thomas(.layoutList(.sceneEmbedded))) {
                            Label("Embedded", systemImage: "rectangle.portrait.topleft.inset.filled")
                        }
                    case .modal: makeDestination(type: .sceneModal)
                    case .banner: makeDestination(type: .sceneBanner)
                    }
                }
            }

            Section("In-App Automations") {
                ForEach(InAppAutomationRoutes.allCases, id: \.self) { route in
                    let type: LayoutType = switch route {
                    case .modal: .messageModal
                    case .banner: .messageBanner
                    case .fullscreen: .messageFullscreen
                    case .html: .messageHTML
                    }
                    
                    makeDestination(type: type)
                }
            }
        }
        .navigationTitle("Layout Viewer")
        .sheet(isPresented: $showError) {
            NavigationStack {
                ScrollView {
                    Text(self.errorMessage ?? "error")
                        .font(.system(.footnote, design: .monospaced))
#if !os(tvOS)
                        .textSelection(.enabled)
#endif
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .navigationTitle("Error")
#if !(os(macOS) || os(tvOS))
                .navigationBarTitleDisplayMode(.inline)
#endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Copy") {
#if os(macOS)
                            let pasteboard = NSPasteboard.general
                            pasteboard.declareTypes([.string], owner: nil)
                            pasteboard.setString(self.errorMessage ?? "", forType: .string)
#elseif !os(tvOS)
                            UIPasteboard.general.string = self.errorMessage
#endif
                        }
                        .disabled(self.errorMessage == nil)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { self.showError = false }
                    }
                }
            }
        }
        .onAppear { self.viewModel.refreshRecent() }
    }
    
    var body: some View {
        layoutsView
    }
    
    @ViewBuilder
    private func makeDestination(type: LayoutType) -> some View {
        let (label, icon) = switch(type) {
        case .sceneEmbedded: ("", "")
        case .sceneModal: ("Modal", "rectangle.portrait.center.inset.filled")
        case .sceneBanner: ("Banner", "rectangle.portrait.topthird.inset.filled")
        case .messageModal: ("Modal", "rectangle.portrait.center.inset.filled")
        case .messageBanner: ("Banner", "rectangle.portrait.topthird.inset.filled")
        case .messageFullscreen: ("Fullscreen", "rectangle.portrait.inset.filled")
        case .messageHTML: ("HTML", "safari.fill")
        }
        
        NavigationLink(value: AppRouter.HomeRoute.thomas(.layoutList(type))) {
            Label(label, systemImage: icon)
        }
    }
}

#Preview {
    ThomasLayoutListView()
}

