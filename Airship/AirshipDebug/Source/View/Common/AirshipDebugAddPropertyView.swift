/* Copyright Airship and Contributors */

import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

struct AirshipDebugAddPropertyView: View {

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

    let onAdd: (String, AirshipJSON) -> Void

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
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Add".localized()) {
                    guard let value = self.value else { return }
                    onAdd(self.key, value)
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(!self.isValid)
            }
        }
    }

    private var value: AirshipJSON? {
        return switch self.propertyType {
        case .bool: .bool(self.boolValue)
        case .number: .number(self.numberValue)
        case .string: .string(self.stringValue)
        case .json: try? AirshipJSON.from(json: self.jsonValue)
        }
    }

    private var isValid: Bool {
        guard !self.key.isEmpty else {
            return false
        }
        return switch self.propertyType {
        case .bool: true
        case .number: true
        case .string: !self.stringValue.isEmpty
        case .json: self.value != nil
        }
    }

    @ViewBuilder
    private func makeValue() -> some View {
        switch self.propertyType {
        case .bool:
            Toggle("\(self.boolValue ? "true": "false")", isOn: self.$boolValue)
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
#if !os(tvOS)
                TextEditor(text: self.$jsonValue.preventWhiteSpace())
                    .frame(maxWidth: .infinity, minHeight: 300)
#endif
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
