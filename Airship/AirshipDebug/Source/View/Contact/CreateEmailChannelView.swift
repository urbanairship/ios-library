/* Copyright Airship and Contributors */

import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

struct CreateEmailChannelView: View {

    enum RegistrationType: String, Equatable, CaseIterable {
        case transactional = "Transactional"
        case commercial = "Commercial"
    }

    @StateObject
    private var viewModel = ViewModel()

    @Environment(\.presentationMode)
    private var presentationMode: Binding<PresentationMode>

    var body: some View {
        Form {
            Section(header: Text("Channel Info".localized())) {
                HStack {
                    Text("Email")
                    Spacer()
                    TextField(
                        "Email",
                        text: self.$viewModel.emailAddress.preventWhiteSpace()
                    )
                    .freeInput()
                }

                Picker(
                    "Registration Type".localized(),
                    selection: self.$viewModel.registrationType
                ) {
                    ForEach(RegistrationType.allCases, id: \.self) { value in
                        Text(value.rawValue.localized())
                    }
                }
                .pickerStyle(.segmented)
            }

            if self.viewModel.registrationType == .commercial {
                Section(header: Text("Commercial Options".localized())) {
                    Toggle("Double Opt-In", isOn: self.$viewModel.doubleOptIn)
                }
            }

            Section(header: Text("Properties".localized())) {
                NavigationLink(
                    "Add Property".localized(),
                    destination: AddPropetyView {
                        self.viewModel.properties[$0] = $1
                    }
                )

                List {
                    let keys = [String](self.viewModel.properties.keys)
                    ForEach(keys, id: \.self) { key in
                        HStack {
                            Text("\(key):")
                            Text(
                                self.viewModel.properties[key]?.stringValue
                                    ?? ""
                            )
                        }
                    }
                    .onDelete {
                        $0.forEach { index in
                            self.viewModel.properties[keys[index]] = nil
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    self.viewModel.createChannel()
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text("Create".localized())
                }
                .disabled(self.viewModel.emailAddress.isEmpty)
            }
        }
        .navigationTitle("Email Channel".localized())
    }

    fileprivate class ViewModel: ObservableObject {
        @Published var emailAddress: String = ""
        @Published var commercial: Bool = false
        @Published var registrationType: RegistrationType = .transactional
        @Published var doubleOptIn: Bool = false
        @Published
        var properties: [String: PropertyValue] = [:]

        func createChannel() {
            guard
                Airship.isFlying,
                !self.emailAddress.isEmpty
            else {
                return
            }

            var options: EmailRegistrationOptions!
            let date = Date()

            switch self.registrationType {
            case .commercial:
                if doubleOptIn {
                    options = EmailRegistrationOptions.options(
                        transactionalOptedIn: date,
                        properties: nil,
                        doubleOptIn: true
                    )
                } else {
                    options = EmailRegistrationOptions.commercialOptions(
                        transactionalOptedIn: date,
                        commercialOptedIn: date,
                        properties: nil
                    )
                }
            case .transactional:
                options = EmailRegistrationOptions.options(
                    transactionalOptedIn: date,
                    properties: nil,
                    doubleOptIn: false
                )
            }

            Airship.contact.registerEmail(
                self.emailAddress,
                options: options
            )
        }
    }
}

private enum PropertyValue: Equatable {
    case bool(Bool)
    case string(String)
    case number(Double)

    var unwrappedValue: Any {
        switch self {
        case .bool(let value): return value
        case .string(let value): return value
        case .number(let value): return value
        }
    }

    var stringValue: String {
        switch self {
        case .bool(let value):
            return value ? "true".localized() : "false".localized()
        case .string(let value): return value
        case .number(let value): return String(value)
        }
    }
}

private struct AddPropetyView: View {

    enum PropertyType: String, Equatable, CaseIterable {
        case bool = "Bool"
        case string = "String"
        case number = "Number"
    }

    @State
    private var key: String = ""

    @State
    private var boolValue: Bool = false

    @State
    private var numberValue: Double = 0

    @State
    private var stringValue: String = ""

    @State
    private var propertyType: PropertyType = .string

    let onAdd: (String, PropertyValue) -> Void

    @Environment(\.presentationMode)
    private var presentationMode: Binding<PresentationMode>

    var body: some View {
        Form {
            HStack {
                Text("Name".localized())
                Spacer()
                TextField(
                    "Name".localized(),
                    text: self.$key.preventWhiteSpace()
                )
                .freeInput()
            }

            Picker("Type".localized(), selection: self.$propertyType) {
                ForEach(PropertyType.allCases, id: \.self) { value in
                    Text(value.rawValue.localized())
                }
            }
            .pickerStyle(.segmented)

            makeValue()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    onAdd(self.key, self.value)
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text("Add".localized())
                }
                .disabled(!self.isValid)
            }
        }
        .navigationTitle("Identifier".localized())
    }

    private var value: PropertyValue {
        switch self.propertyType {
        case .bool: return .bool(self.boolValue)
        case .number: return .number(self.numberValue)
        case .string: return .string(self.stringValue)
        }
    }
    private var isValid: Bool {
        guard !self.key.isEmpty else {
            return false
        }
        switch self.propertyType {
        case .bool: return true
        case .number: return true
        case .string: return !self.stringValue.isEmpty
        }
    }

    @ViewBuilder
    private func makeValue() -> some View {
        switch self.propertyType {
        case .bool:
            Toggle(self.value.stringValue, isOn: self.$boolValue)
        case .string:
            HStack {
                Text("String".localized())
                Spacer()
                TextField(
                    "String".localized(),
                    text: self.$stringValue.preventWhiteSpace()
                )
                .freeInput()
            }
        case .number:
            HStack {
                Text("Number".localized())
                Spacer()
                TextField(
                    "Number".localized(),
                    value: self.$numberValue,
                    formatter: NumberFormatter()
                )
                .keyboardType(.numberPad)
            }
        }
    }
}
