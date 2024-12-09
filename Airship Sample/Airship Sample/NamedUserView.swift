/* Copyright Urban Airship and Contributors */

import AirshipCore
import AirshipPreferenceCenter
import Foundation
import SwiftUI

struct NamedUserView: View {

    @StateObject
    private var viewModel: ViewModel = ViewModel()


    private func updateNamedUser() {
        let normalized = self.viewModel.namedUserID.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        if !normalized.isEmpty {
            Airship.contact.identify(normalized)
        } else {
            Airship.contact.reset()
        }
    }

    @ViewBuilder
    private func makeTextInput() -> some View {
        TextField("Named User", text: self.$viewModel.namedUserID)
            .onSubmit {
                updateNamedUser()
            }
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(
                "A named user is an identifier that maps multiple devices and channels to a specific individual."
            )
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


    @MainActor
    private class ViewModel: ObservableObject {
        @Published
        public var namedUserID: String = ""

        init() {
            Task { @MainActor in
                self.namedUserID = await Airship.contact.namedUserID ?? ""
            }
        }
    }
}
