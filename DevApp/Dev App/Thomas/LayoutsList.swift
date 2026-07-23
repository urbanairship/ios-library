/* Copyright Airship and Contributors */

import AirshipCore
import SwiftUI

struct LayoutsList: View {

    @ObservedObject
    private var viewModel: ViewModel

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
            }
        }
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

