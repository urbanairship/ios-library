/* Copyright Urban Airship and Contributors */

import Foundation
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

struct NamedUserDebugView: View {

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


    var body: some View {
        let title = "Named User".localized()


        Form {
            Section(
                header: Text(""),
                footer: Text("An empty value does not indicate the device does not have a named user. The SDK only knows about the Named User ID if set through the SDK.".localized())
            ) {
                if #available(iOS 15.0, *) {
                    TextField(title, text: self.$namedUserID)
                        .onSubmit {
                            updateNamedUser()
                        }
                        .freeInput()
                } else {
                    TextField(title, text: self.$namedUserID) {
                        updateNamedUser()
                    }
                }
            }
        }
        .navigationTitle(title)
    }
}


