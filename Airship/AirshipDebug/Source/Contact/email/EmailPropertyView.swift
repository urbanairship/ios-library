/* Copyright Airship and Contributors */

import SwiftUI

@available(iOS 13.0, *)
struct EmailPropertyView: View {
    @Binding var propertyType: EmailPropertyType
    
    var body: some View {
        HStack(spacing: 5) {
            SelectButton(isSelected: .constant(propertyType == EmailPropertyType.stringType), color: .blue, text: "String")
                .onTapGesture {
                    onButtonTapped(propertyType: EmailPropertyType.stringType)
                }
            SelectButton(isSelected: .constant(propertyType == EmailPropertyType.intType), color: .blue, text: "Number")
                .onTapGesture {
                    onButtonTapped(propertyType: EmailPropertyType.intType)
                }
            SelectButton(isSelected: .constant(propertyType == EmailPropertyType.boolType), color: .blue, text: "Boolean")
                .onTapGesture {
                    onButtonTapped(propertyType: EmailPropertyType.boolType)
                }
        }
    }
    
    private func onButtonTapped(propertyType: EmailPropertyType) {
        withAnimation {
            self.propertyType = propertyType
        }
    }
}

@available(iOS 13.0, *)
struct EmailPropertyView_Previews: PreviewProvider {
    static var previews: some View {
        EmailPropertyView(propertyType: .constant(EmailPropertyType.stringType))
    }
}
