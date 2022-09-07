/* Copyright Urban Airship and Contributors */

import Foundation
import AirshipPreferenceCenter
import SwiftUI
import AirshipCore

struct NamedUserView: View {

    @State
    private var namedUserID: String = Airship.contact.namedUserID ?? ""

    private func updateNamedUser() {
        let normalized = namedUserID.trimmingCharacters(in: .whitespacesAndNewlines)

        if !normalized.isEmpty {
            Airship.contact.identify(normalized)
        } else {
            Airship.contact.reset()
        }
    }

    @ViewBuilder
    private func makeTextInput() -> some View {
        if #available(iOS 15.0, *) {
            TextField("Named User", text: self.$namedUserID)
                .onSubmit {
                    updateNamedUser()
                }
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
        } else {
            TextField("Named User", text: self.$namedUserID) {
                updateNamedUser()
            }

        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("A named user is an identifier that maps multiple devices and channels to a specific individual.")
                .multilineTextAlignment(.leading)

            makeTextInput()
                .padding()
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.secondary, lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("Named User")
        .padding()
    }
}


