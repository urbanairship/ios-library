/* Copyright Airship and Contributors */

import AirshipCore
import SwiftUI
@_spi(AirshipInternal) import AirshipScenes
@_spi(AirshipInternal) import AirshipSceneRenderer

struct LayoutsList: View {

    @ObservedObject
    private var viewModel: ViewModel

    @State
    private var mcModeLayout: MCModeLayout?

    init(
        layoutType: LayoutType,
        onOpen: @escaping @MainActor (LayoutFile) -> Void
    ) {
        viewModel = .init(layoutType: layoutType, onOpen: onOpen)
    }

    var body: some View {
        List {
            ForEach(viewModel.layouts, id: \.self) { layout in
                Button(layout.fileName) {
                    open(layout)
                }
                .contextMenu {
                    Button("Open in MC mode") {
                        openInMCMode(layout)
                    }
                }
            }
        }
        .mcModePresentation(item: $mcModeLayout)
        .sheet(isPresented: Binding(get: { viewModel.openError != nil }, set: { if !$0 { viewModel.openError = nil } })) {
            NavigationStack {
                ScrollView {
                    Text(viewModel.openError?.localizedDescription ?? "")
                        .font(.system(.footnote, design: .monospaced))
#if !os(tvOS)
                        .textSelection(.enabled)
#endif
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .navigationTitle("Error")
#if !os(macOS) && !os(tvOS)
                .navigationBarTitleDisplayMode(.inline)
#endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Copy") {
#if os(macOS)
                            let pasteboard = NSPasteboard.general
                            pasteboard.declareTypes([.string], owner: nil)
                            pasteboard.setString(viewModel.openError?.localizedDescription ?? "", forType: .string)
#elseif !os(tvOS)
                            UIPasteboard.general.string = viewModel.openError?.localizedDescription
#endif
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { viewModel.openError = nil }
                    }
                }
            }
        }
    }

    func open(_ layout: LayoutFile, addToRecents: Bool = true) {
        Task { @MainActor in
            do {
                try await viewModel.openLayout(layout)
            } catch {
                viewModel.openError = error
            }
        }
    }

    /// Renders the layout through the same path Message Center uses for native content
    /// (`AirshipSimpleLayoutView`) rather than the normal presentation pipeline, so the two can be
    /// compared against the same file.
    private func openInMCMode(_ layout: LayoutFile) {
        do {
            self.mcModeLayout = MCModeLayout(
                layout: try layout.loadAirshipLayout(),
                title: layout.fileName
            )
        } catch {
            viewModel.openError = error
        }
    }
}

struct MCModeLayout: Identifiable {
    let id: UUID = UUID()
    let layout: AirshipLayout
    let title: String
}

extension View {
    /// `fullScreenCover` where it exists, so MC mode gets the whole screen -- a page sheet would
    /// change the very geometry being compared.
    @ViewBuilder
    func mcModePresentation(item: Binding<MCModeLayout?>) -> some View {
#if os(macOS)
        self.sheet(item: item) { ThomasMCModeView(layout: $0.layout, title: $0.title) }
#else
        self.fullScreenCover(item: item) { ThomasMCModeView(layout: $0.layout, title: $0.title) }
#endif
    }
}

/// Hosts a layout the way `MessageCenterMessageView` hosts native message content: a bare `ZStack`
/// with no frame of its own, pushed under a navigation bar, under a tab bar. Mirroring that chrome
/// is the point -- it is what the scene is actually measured against in Message Center, tab bar
/// height and all.
struct ThomasMCModeView: View {

    private let layout: AirshipLayout
    private let title: String

    @Environment(\.dismiss)
    private var dismiss

    @StateObject
    private var layoutViewModel: AirshipSimpleLayoutViewModel

    init(layout: AirshipLayout, title: String) {
        self.layout = layout
        self.title = title
        self._layoutViewModel = StateObject(
            wrappedValue: AirshipSimpleLayoutViewModel(
                delegate: MCModeThomasDelegate(),
                extensions: DefaultThomasExtensions()
            )
        )
    }

    var body: some View {
        TabView {
            NavigationStack {
                ZStack {
                    AirshipSimpleLayoutView(
                        layout: layout,
                        viewModel: layoutViewModel
                    )
                }
                .navigationTitle(title)
#if !os(macOS) && !os(tvOS)
                .navigationBarTitleDisplayMode(.inline)
#endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .tabItem {
                Label("Message Center", systemImage: "tray.fill")
            }

            Text("Junk")
                .tabItem {
                    Label("Junk", systemImage: "questionmark.circle")
                }

            Text("More Junk")
                .tabItem {
                    Label("More Junk", systemImage: "ellipsis.circle")
                }
        }
    }
}

/// Reporting goes nowhere in MC mode: the point is the layout, and there is no message to report
/// against.
@MainActor
private final class MCModeThomasDelegate: ThomasDelegate {
    func onVisibilityChanged(isVisible: Bool, isForegrounded: Bool) {}
    func onReportingEvent(_ event: ThomasReportingEvent) {}
    func onDismissed(cancel: Bool) {}
}

@MainActor
private class ViewModel: ObservableObject {
    let layoutLoader = LayoutLoader()
    let layouts: [LayoutFile]
    let onOpen: @MainActor (LayoutFile) -> Void

    @Published
    var openError: (any Error)?

    init(layoutType: LayoutType, onOpen: @escaping @MainActor (LayoutFile) -> Void) {
        layouts = layoutLoader.load(type: layoutType)
        self.onOpen = onOpen
    }

    func openLayout(_ layout: LayoutFile) async throws {
        try await layout.open()
        onOpen(layout)
    }
}

