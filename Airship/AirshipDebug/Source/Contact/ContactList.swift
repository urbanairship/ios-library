/* Copyright Airship and Contributors */

import SwiftUI

@available(iOS 13.0.0, *)
struct ContactList: View {
    var body: some View {
        List {
            NavigationLink(destination: OpenView()) {
                VStack(alignment: .leading) {
                    Text("Open")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Register an open channel to the contact")
                        .font(.system(size: 12))
                }
            }
            NavigationLink(destination: SmsView()) {
                VStack(alignment: .leading) {
                    Text("SMS")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Register an sms to the contact")
                        .font(.system(size: 12))
                }
            }
            NavigationLink(destination: EmailView()) {
                VStack(alignment: .leading) {
                    Text("Email")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Register an email to the contact")
                        .font(.system(size: 12))
                }
            }
        }
    }
}

@available(iOS 13.0.0, *)
struct ContactList_Previews: PreviewProvider {
    static var previews: some View {
        ContactList()
    }
}
