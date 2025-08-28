/* Copyright Urban Airship and Contributors */


public import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

public struct NamedUserDebugView: View {

    public init() {}
    
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

    public var body: some View {
        let title = "Named User".localized()

        Form {
            Section(
                header: Text(""),
                footer: Text(
                    "An empty value does not indicate the device does not have a named user. The SDK only knows about the Named User ID if set through the SDK."
                        .localized()
                )
            ) {
                TextField(title, text: self.$viewModel.namedUserID)
                    .onSubmit {
                        updateNamedUser()
                    }
                    .freeInput()
            }
        }
        .navigationTitle(title)
    }


    @MainActor
    private class ViewModel: ObservableObject {
        @Published
        public var namedUserID: String = ""

        init() {
            Task { @MainActor in
                if !Airship.isFlying { return }
                self.namedUserID = await Airship.contact.namedUserID ?? ""
            }
        }
    }
}

#Preview {
    NamedUserDebugView()
}
