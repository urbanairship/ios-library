/* Copyright Airship and Contributors */

import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

struct CreateSMSChannelView: View {
    @Environment(\.presentationMode)
    private var presentationMode: Binding<PresentationMode>

    @State var phoneNumber: String = ""
    @State var senderID: String = ""

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
                    .keyboardType(.phonePad)
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
            ToolbarItem(placement: .navigationBarTrailing) {
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

struct CreateSMSChannelView_Previews: PreviewProvider {
    static var previews: some View {
        CreateSMSChannelView()
    }
}
