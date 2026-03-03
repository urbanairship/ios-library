/* Copyright Airship and Contributors */

import SwiftUI
import AirshipCore

struct AirshipDebugAddSMSChannelView: View {
    @Environment(\.presentationMode)
    private var presentationMode: Binding<PresentationMode>

    @State 
    private var phoneNumber: String = ""

    @State
    private var senderID: String = ""

    var body: some View {
        Form {
            Section(header: Text("Channel Info".localized())) {
                HStack {
                    Text("MSISDN".localized())
                    Spacer()
                    TextField(
                        "MSISDN".localized(),
                        text: self.$phoneNumber
                    )
#if !os(macOS)
                    .keyboardType(.phonePad)
#endif
                    .freeInput()
                }

                HStack {
                    Text("Sender ID")
                    Spacer()
                    TextField(
                        "Sender ID",
                        text: self.$senderID.preventWhiteSpace()
                    )
                    .freeInput()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    createChannel()
                } label: {
                    Text("Create".localized())
                }
                .disabled(senderID.isEmpty || phoneNumber.isEmpty)
            }
        }
        .navigationTitle("SMS Channel".localized())
    }

    func createChannel() {
        guard
            Airship.isFlying,
            !senderID.isEmpty,
            !phoneNumber.isEmpty
        else {
            return
        }
        let options = SMSRegistrationOptions.optIn(senderID: senderID)
        Airship.contact.registerSMS(phoneNumber, options: options)
    }
}

#Preview {
    AirshipDebugAddSMSChannelView()
}

