/* Copyright Airship and Contributors */

import AirshipCore
import SwiftUI

struct LayoutsList: View {

    @ObservedObject
    private var viewModel: ViewModel
    
    @State var errorMessage: String?
    @State var showError: Bool = false

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
    }
    
    func open(_ layout: LayoutFile, addToRecents: Bool = true) {
        do {
            try viewModel.openLayout(layout)
        } catch {
            self.showError = true
            self.errorMessage = "Failed to open layout \(error)"
        }
    }
}

@MainActor
private class ViewModel: ObservableObject {
    let layoutLoader = LayoutLoader()
    let layouts: [LayoutFile]
    let onOpen: @MainActor (LayoutFile) -> Void
    
    init(layoutType: LayoutType, onOpen: @escaping @MainActor (LayoutFile) -> Void) {
        layouts = layoutLoader.load(type: layoutType)
        self.onOpen = onOpen
    }
    
    func openLayout(_ layout: LayoutFile) throws {
        try layout.open()
        onOpen(layout)
    }
}

