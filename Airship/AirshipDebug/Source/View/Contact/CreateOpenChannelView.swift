/* Copyright Airship and Contributors */

import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

import Combine

struct CreateOpenChannelView: View {

    @StateObject
    private var viewModel = ViewModel()

    @Environment(\.presentationMode)
    private var presentationMode: Binding<PresentationMode>

    var body: some View {
        Form {

            Section(header: Text("Channel Info".localized())) {
                HStack {
                    Text("Platform")
                    Spacer()
                    TextField(
                        "Platform",
                        text: self.$viewModel.platformName.preventWhiteSpace()
                    )
                    .freeInput()
                }

                HStack {
                    Text("Address")
                    Spacer()
                    TextField(
                        "Address",
                        text: self.$viewModel.address.preventWhiteSpace()
                    )
                    .freeInput()
                }
            }

            Section(header: Text("Identifiers".localized())) {
                NavigationLink(
                    "Add Identifier".localized(),
                    destination: AddIdentifierView {
                        self.viewModel.identifiers[$0] = $1
                    }
                )

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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    self.viewModel.createChannel()
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text("Create".localized())
                }
                .disabled(
                    self.viewModel.address.isEmpty
                        || self.viewModel.platformName.isEmpty
                )
            }
        }
        .navigationTitle("Open Channel".localized())
    }

    @MainActor
    class ViewModel: ObservableObject {
        @Published var identifiers: [String: String] = [:]
        @Published var address: String = ""
        @Published var platformName: String = ""

        func createChannel() {
            guard
                Airship.isFlying,
                !self.address.isEmpty,
                !self.platformName.isEmpty
            else {
                return
            }

            let options = OpenRegistrationOptions.optIn(
                platformName: self.platformName,
                identifiers: identifiers
            )

            Airship.contact.registerOpen(
                self.address,
                options: options
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
