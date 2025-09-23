/* Copyright Airship and Contributors */

import AirshipCore
import Foundation
import SwiftUI

@MainActor
struct NamedUserView: View {

    @StateObject
    private var viewModel: ViewModel = ViewModel()

    @ViewBuilder
    private func makeTextInput() -> some View {
        TextField("Named User", text: self.$viewModel.namedUserID)
            .onSubmit {
                viewModel.apply()
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
            Airship.onReady {
                Task { @MainActor [weak self] in
                    self?.namedUserID = await Airship.contact.namedUserID ?? ""
                }
            }
        }

        func apply() {
            let normalized = self.namedUserID.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            if !normalized.isEmpty {
                Airship.contact.identify(normalized)
            } else {
                Airship.contact.reset()
            }
        }
    }
}
