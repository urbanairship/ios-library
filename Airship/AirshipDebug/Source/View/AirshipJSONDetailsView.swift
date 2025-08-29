
import Foundation
import SwiftUI


#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

struct AirshipJSONDetailsView: View {
    let payload: AirshipJSON
    let title: String

    @State
    private var toastMessage: AirshipToast.Message? = nil

    @ViewBuilder
    var body: some View {
        Form {
            Section(header: Text("Details".localized())) {
                AirshipJSONView(json: payload)
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Copy") {
                    copyToClipboard(value: payload.prettyString)
                }
            }
        }
        .toastable($toastMessage)
    }

    func copyToClipboard(value: String?) {
        guard let value = value else {
            return
        }

        value.pastleboard()
        self.toastMessage = AirshipToast.Message(
            id: UUID().uuidString,
            text: "Copied to pasteboard!".localized(),
            duration: 1.0
        )
    }
}

#Preview {
    AirshipJSONDetailsView(
        payload: .object(["key": .string("value")]),
        title: "Preview")
}
