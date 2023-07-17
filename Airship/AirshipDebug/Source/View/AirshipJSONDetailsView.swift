
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
                AirshipJSONView(json: try! AirshipJSON.wrap(payload))
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
        .overlay(AirshipToast(message: self.$toastMessage))
    }

    func copyToClipboard(value: String?) {
        guard let value = value else {
            return
        }

        UIPasteboard.general.string = value
        self.toastMessage = AirshipToast.Message(
            id: UUID().uuidString,
            text: "Copied to pasteboard!".localized(),
            duration: 1.0
        )
    }
}
