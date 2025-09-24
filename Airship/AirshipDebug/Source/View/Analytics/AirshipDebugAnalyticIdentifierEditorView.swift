/* Copyright Airship and Contributors */

import SwiftUI
import Combine
import AirshipCore

struct AirshipDebugAnalyticIdentifierEditorView: View {

    @StateObject
    private var viewModel = ViewModel()

    @State
    private var shouldPresentPropetySheet: Bool = false

    var body: some View {
        Form {
            Section(header: Text("Identifiers".localized())) {
                Button("Add Identifier".localized()) {
                    self.shouldPresentPropetySheet = true
                }
                .sheet(isPresented: self.$shouldPresentPropetySheet) {
                    NavigationStack {
                        AirshipDebugAddStringPropertyView {
                            self.viewModel.identifiers[$0] = $1
                        }
                        .navigationTitle("New Identifier")
#if !os(tvOS)
                        .navigationBarTitleDisplayMode(.inline)
#endif
                    }
                    .presentationDetents([.medium])
                }

                List {
                    let keys = [String](self.viewModel.identifiers.keys)
                    ForEach(keys, id: \.self) { key in
                        HStack {
                            Text("\(key):")
                            Text(self.viewModel.identifiers[key] ?? "")
                        }
                    }
                    .onDelete {
                        $0.forEach { index in
                            self.viewModel.identifiers[keys[index]] = nil
                        }
                    }
                }
            }
        }
        .navigationTitle("Analytic Identifiers".localized())
    }

    @MainActor
    class ViewModel: ObservableObject {
        @Published var identifiers: [String: String] {
            didSet {
                save()
            }
        }

        init() {
            if Airship.isFlying {
                self.identifiers =
                Airship.analytics.currentAssociatedDeviceIdentifiers().allIDs
            } else {
                self.identifiers = [:]
            }
        }

        func save() {
            guard Airship.isFlying else { return }
            Airship.analytics.associateDeviceIdentifiers(
                AssociatedIdentifiers(identifiers: self.identifiers)
            )
        }
    }
}

private struct AddIdentifierView: View {

    @State
    private var key: String = ""

    @State
    private var value: String = ""

    let onAdd: (String, String) -> Void

    @Environment(\.presentationMode)
    private var presentationMode: Binding<PresentationMode>

    var body: some View {
        Form {
            HStack {
                Text("Key".localized())
                Spacer()
                TextField(
                    "Key".localized(),
                    text: self.$key.preventWhiteSpace()
                )
                .freeInput()
            }
            HStack {
                Text("Value".localized())
                Spacer()
                TextField(
                    "Value".localized(),
                    text: self.$value.preventWhiteSpace()
                )
                .freeInput()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    onAdd(key, value)
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text("Add".localized())
                }
                .disabled(key.isEmpty || value.isEmpty)
            }
        }
        .navigationTitle("Identifier".localized())

    }
}

#Preview {
    AirshipDebugAnalyticIdentifierEditorView()
}
