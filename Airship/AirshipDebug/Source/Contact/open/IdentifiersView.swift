/* Copyright Airship and Contributors */

import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

@available(iOS 13.0, *)
struct IdentifiersView: View {
    @State var key: String = ""
    @State var value: String = ""
    
    var identifiers: Identifiers
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Identifier")
            TextField("Key", text: $key)
            TextField("Value", text: $value)
            HStack {
                Button("Add") {
                    identifiers.addIdentifier(key: key, value: value)
                }
                Button("Remove") {
                    identifiers.removeIdentifier(key: key, value: value)
                }
            }
            Spacer()
        }
    }
}
