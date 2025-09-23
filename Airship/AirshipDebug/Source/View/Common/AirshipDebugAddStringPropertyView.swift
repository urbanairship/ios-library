/* Copyright Airship and Contributors */

import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

struct AirshipDebugAddStringPropertyView: View {

    @State
    private var key: String = ""

    @State
    private var value: String = ""

    let onAdd: (String, String) -> Void

    private var isValid: Bool {
        return !key.isEmpty && !value.isEmpty
    }

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
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Add".localized()) {
                    onAdd(self.key, value)
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(!self.isValid)
            }
        }

    }
}
