/* Copyright Airship and Contributors */

import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

@available(iOS 13.0, *)
struct SmsView: View {
    @State var phoneNumber: String = ""
    @State var senderId: String = ""
    
    var body: some View {
        VStack(alignment: .leading) {
            TextField("Phone number", text: $phoneNumber)
            TextField("Sender ID", text: $senderId)
            Button("CREATE") {
                Airship.contact.registerSMS(phoneNumber, options: SMSRegistrationOptions.optIn(senderID: senderId))
            }
            .frame(width: 85, height: 30)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            Spacer()
        }
    }
}

@available(iOS 13.0.0, *)
struct SmsView_Previews: PreviewProvider {
    static var previews: some View {
        SmsView()
    }
}
