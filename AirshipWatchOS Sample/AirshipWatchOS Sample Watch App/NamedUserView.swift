/* Copyright Urban Airship and Contributors */

import AirshipCore

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
        TextField("Named User", text:self.$viewModel.namedUserID) {
            updateNamedUser()
        }
    }

    var body: some View {
        VStack() {
            Text("Named User")
                .padding(.bottom)

            makeTextInput()
        }
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
