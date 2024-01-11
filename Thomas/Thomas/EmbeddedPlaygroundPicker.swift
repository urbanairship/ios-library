/* Copyright Urban Airship and Contributors */

import SwiftUI
import Foundation

struct EmbeddedPlaygroundPicker: View {
    @Binding var selectedID: String
    var embeddedIds: [String]

    var body: some View {
        VStack {
            Picker("Embedded View", selection: $selectedID) {
                ForEach(embeddedIds, id: \.self) { id in
                    Text(id).tag(id)
                }
            }
            .pickerStyle(WheelPickerStyle())
        }
        .onAppear {
            if !embeddedIds.isEmpty {
                selectedID = embeddedIds.first!
            }
        }
    }
}

#Preview {
    EmbeddedPlaygroundPicker(selectedID:Binding.constant("home_rating"), embeddedIds: ["home_rating", "home_special_offer"])
}
