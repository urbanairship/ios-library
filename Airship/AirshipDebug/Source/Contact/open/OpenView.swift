/* Copyright Airship and Contributors */

import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

@available(iOS 13.0, *)
struct OpenView: View {
    @State var address: String = ""
    @State var platformName: String = ""
    @StateObject var identifiers = Identifiers()
    
    var body: some View {
        VStack(alignment: .leading) {
            TextField("Address", text: $address)
            TextField("Platform name", text: $platformName)
            Button("CREATE") {
                let options = OpenRegistrationOptions.optIn(platformName: platformName, identifiers: identifiers.getIdentifiers())
                
                Airship.contact.registerOpen(address, options: options)
            }
            .frame(width: 85, height: 30)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            
            HStack {
                Text("Identifiers")
                    .font(.system(size: 18, weight: .semibold))
                NavigationLink(destination: IdentifiersView(identifiers: identifiers)) {
                    Text("Add Identifiers")
                }
            }
            
            ForEach(identifiers.getIdentifiers().sorted(by: >), id: \.key) { item in
                HStack {
                    Text(item.key)
                }
            }
            Spacer()
        }
    }
}

@available(iOS 13.0.0, *)
struct OpenView_Previews: PreviewProvider {
    static var previews: some View {
        OpenView()
    }
}
