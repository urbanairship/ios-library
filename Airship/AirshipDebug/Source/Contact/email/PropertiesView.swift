/* Copyright Airship and Contributors */

import SwiftUI

@available(iOS 13.0.0, *)
struct PropertiesView: View {
    var properties: Properties
    
    @State var propertyType = EmailPropertyType.stringType
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Property Type")
            EmailPropertyView(propertyType: $propertyType)
            
            switch propertyType {
            case .stringType:
                StringTabView(properties: properties)
            case .intType:
                NumberTabView(properties: properties)
            case .boolType:
                BoolTabView(properties: properties)
            }
            Spacer()
        }
    }
}

enum EmailPropertyType: Int {
    case stringType = 0, intType, boolType
}

@available(iOS 13.0.0, *)
struct StringTabView: View {
    @State var key: String = ""
    @State var value: String = ""
    var properties: Properties
    
    var body: some View {
        TextField("Name", text: $key)
        TextField("Value", text: $value)
        HStack {
            Button("Add") {
                properties.addProperty(key: key, value: value)
            }
            Button("Remove") {
                properties.removeProperty(key: key)
            }
        }
    }
}

@available(iOS 13.0.0, *)
struct NumberTabView: View {
    @State var key: String = ""
    @State var value: String = ""
    var properties: Properties
    
    var body: some View {
        TextField("Name", text: $key)
        TextField("Value", text: $value)
            .keyboardType(.decimalPad)
        HStack {
            Button("Add") {
                let numValue = Int(value) ?? 0
                properties.addProperty(key: key, value: numValue)
            }
            Button("Remove") {
                properties.removeProperty(key: key)
            }
        }
    }
}

@available(iOS 13.0.0, *)
struct BoolTabView: View {
    @State var key: String = ""
    @State var value: Bool = true
    var properties: Properties
    
    var body: some View {
        VStack {
            TextField("Name", text: $key)
            HStack(spacing: 10) {
                SelectButton(isSelected: .constant(value == true), color: .blue, text: "True")
                    .onTapGesture {
                        value = true
                    }
                SelectButton(isSelected: .constant(value == false), color: .blue, text: "False")
                    .onTapGesture {
                        value = false
                    }
                Spacer()
            }
            HStack {
                Button("Add") {
                    properties.addProperty(key: key, value: value)
                }
                Button("Remove") {
                    properties.removeProperty(key: key)
                }
                Spacer()
            }
        }
    }
}

@available(iOS 13.0.0, *)
struct PropertiesView_Previews: PreviewProvider {
    static var previews: some View {
        let properties = Properties()
        PropertiesView(properties: properties)
    }
}
