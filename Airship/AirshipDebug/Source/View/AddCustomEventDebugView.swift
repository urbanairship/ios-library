import AirshipCore
import Foundation
import SwiftUI

public struct AddCustomEventView: View {

    @StateObject
    private var viewModel = ViewModel()

    @Environment(\.presentationMode)
    private var presentationMode: Binding<PresentationMode>

    public init() {}

    @ViewBuilder
    func makeTextInput(title: String, binding: Binding<String>) -> some View {
        HStack {
            Text(title.lowercased())
            Spacer()
            TextField(title.lowercased(), text: binding.preventWhiteSpace())
                .freeInput()
        }
    }

    @ViewBuilder
    func makeNumberInput(title: String, binding: Binding<Double>) -> some View {
        HStack {
            Text(title.lowercased())
            Spacer()
            TextField(
                title.lowercased(),
                value: binding,
                formatter: NumberFormatter()
            )
            .keyboardType(.numberPad)
        }
    }

    public var body: some View {
        Form {
            Section(header: Text("Event Properties".localized())) {
                makeTextInput(
                    title: "Event Name",
                    binding: self.$viewModel.eventName
                )
                makeNumberInput(
                    title: "Event Value",
                    binding: self.$viewModel.eventValue
                )
                makeTextInput(
                    title: "Transaction ID",
                    binding: self.$viewModel.transactionID
                )
                makeTextInput(
                    title: "Interaction ID",
                    binding: self.$viewModel.interactionID
                )
                makeTextInput(
                    title: "Interaction Type",
                    binding: self.$viewModel.interactionType
                )
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
                    self.viewModel.createEvent()
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text("Create".localized())
                }
                .disabled(self.viewModel.eventName.isEmpty)
            }
        }
        .navigationTitle("Custom Event".localized())
    }

    @MainActor
    fileprivate class ViewModel: ObservableObject {
        @Published var eventName: String = ""
        @Published var eventValue: Double = 1.0
        @Published var interactionID: String = ""
        @Published var interactionType: String = ""
        @Published var transactionID: String = ""

        var properties: [String: PropertyValue] = [:]

        func createEvent() {
            guard
                Airship.isFlying,
                !self.eventName.isEmpty
            else {
                return
            }

            let event = CustomEvent(
                name: self.eventName,
                value: self.eventValue as NSNumber
            )
            if !self.transactionID.isEmpty {
                event.transactionID = self.transactionID
            }
            if !self.interactionID.isEmpty && !self.interactionType.isEmpty {
                event.interactionID = self.interactionID
                event.interactionType = self.interactionType
            }
            event.properties = self.properties.mapValues { $0.unwrappedValue }

            event.track()
        }
    }
}

private enum PropertyValue: Equatable {
    case bool(Bool)
    case string(String)
    case number(Double)
    case json(AnyHashable)

    var unwrappedValue: Any {
        switch self {
        case .bool(let value): return value
        case .string(let value): return value
        case .number(let value): return value
        case .json(let value): return value
        }
    }

    var stringValue: String {
        switch self {
        case .bool(let value):
            return value ? "true".localized() : "false".localized()
        case .string(let value): return value
        case .number(let value): return String(value)
        case .json(let value):
            return (try? AirshipJSONUtils.string(value, options: .prettyPrinted)) ?? ""
        }
    }
}

private struct AddPropetyView: View {

    enum PropertyType: String, Equatable, CaseIterable {
        case bool = "Bool"
        case string = "String"
        case number = "Number"
        case json = "JSON"
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
    private var jsonValue: String = ""

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
        case .json:
            return .json(AirshipJSONUtils.object(self.jsonValue) as! AnyHashable)
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
        case .json:
            return !self.jsonValue.isEmpty
                && (AirshipJSONUtils.object(self.jsonValue)) != nil
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
        case .json:
            VStack {
                Text("JSON".localized())
                Spacer()
                TextEditor(text: self.$jsonValue.preventWhiteSpace())
                    .frame(maxWidth: .infinity, minHeight: 300)
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
