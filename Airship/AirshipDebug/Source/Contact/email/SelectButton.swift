/* Copyright Airship and Contributors */

import SwiftUI

@available(iOS 13.0, *)
struct SelectButton: View {
    @Binding var isSelected: Bool
    @State var color: Color
    @State var text: String
    
    var body: some View {
        ZStack {
            Capsule()
                .frame(height: 33)
                .frame(width: 70)
                .foregroundColor(isSelected ? color: .gray)
            Text(text)
                .foregroundColor(.white)
        }
    }
}

@available(iOS 13.0, *)
struct SelectButton_Previews: PreviewProvider {
    static var previews: some View {
        SelectButton(isSelected: .constant(false), color: .blue, text: "String")
    }
}
