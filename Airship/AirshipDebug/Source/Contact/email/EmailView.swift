/* Copyright Airship and Contributors */

import SwiftUI


#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

@available(iOS 13.0.0, *)
struct EmailView: View {
    @State var email: String = ""
    @State private var transactional = false;
    @State private var commercial = false;
    @ObservedObject var properties = Properties()
    
    var body: some View {
        VStack(alignment: .leading) {
            TextField("Email Address", text: $email)
            Toggle("Transactional", isOn: $transactional)
            Toggle("Commercial", isOn: $commercial)
            Button("CREATE") {
                let options = EmailRegistrationOptions.commercialOptions(transactionalOptedIn: transactional ? Date() : nil, commercialOptedIn: commercial ? Date() : nil, properties: properties.getProperties())
                Airship.contact.registerEmail(email, options: options)
            }
            .frame(width: 85, height: 30)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            
            HStack {
                Text("Properties")
                    .font(.system(size: 18, weight: .semibold))
                NavigationLink(destination: PropertiesView(properties: properties)) {
                    Text("Add Property")
                }
            }
            
            ForEach(Array(properties.getProperties().keys.enumerated()), id:\.element) { _, key in
                HStack {
                    Text(key)
                }
            }
            Spacer()
        }
    }
}

@available(iOS 13.0.0, *)
struct EmailView_Previews: PreviewProvider {
    static var previews: some View {
        EmailView()
    }
}
