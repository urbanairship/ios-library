/* Copyright Urban Airship and Contributors */

import Foundation
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

struct AttributesDebugView: View {

    let editorFactory: () -> AttributesEditor?

    private enum AttributeAction: String, Equatable, CaseIterable {
        case add = "Add"
        case remove = "Remove"
    }

    private enum AttributeType: String, Equatable, CaseIterable {
        case text = "Text"
        case number = "Number"
        case date = "Date"
    }

    @State
    private var attribute: String = ""

    @State
    private var action: AttributeAction = .add

    @State
    private var type: AttributeType = .text

    @State
    private var date = Date()

    @State
    private var text: String = ""

    @State
    private var number: Double = 0.0

    @ViewBuilder
    func makeValue() -> some View {
        switch self.type {
        case .date:
            DatePicker(
                "Date".localized(),
                selection: $date,
                displayedComponents: [.date, .hourAndMinute]
            )
        case .text:
            HStack {
                Text("Text")
                Spacer()
                TextField(
                    "Value".localized(),
                    text: self.$text.preventWhiteSpace()
                )
                .freeInput()
            }
        case .number:
            HStack {
                Text("Number")
                Spacer()
                TextField(
                    "Value".localized(),
                    value: self.$number,
                    formatter: NumberFormatter()
                )
                .keyboardType(.numberPad)
            }
        }
    }

    var body: some View {
        Form {
            Section(header: Text("Attribute Info".localized())) {
                Picker("Action".localized(), selection: $action) {
                    ForEach(AttributeAction.allCases, id: \.self) { value in
                        Text(value.rawValue.localized())
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("Attribute".localized())
                    Spacer()
                    TextField(
                        "Attribute Name".localized(),
                        text: self.$attribute.preventWhiteSpace()
                    )
                    .freeInput()
                }

                if self.action == .add {
                    Picker("Type".localized(), selection: $type) {
                        ForEach(AttributeType.allCases, id: \.self) { value in
                            Text(value.rawValue.localized())
                        }
                    }
                    .pickerStyle(.segmented)

                    makeValue()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    apply()
                } label: {
                    Text("Apply".localized())
                }
                .disabled(!isValid())
            }
        }
        .navigationTitle("Attributes".localized())
    }

    private func isValid() -> Bool {
        guard !attribute.isEmpty else { return false }

        switch self.action {
        case .add:
            switch self.type {
            case .number:
                return true
            case .text:
                return !self.text.isEmpty
            case .date:
                return true
            }
        case .remove:
            return true
        }
    }
    private func apply() {
        let editor = editorFactory()
        switch self.action {
        case .add:
            switch self.type {
            case .number:
                editor?.set(double: self.number, attribute: self.attribute)
            case .text:
                editor?.set(string: self.text, attribute: self.attribute)
            case .date:
                editor?.set(date: self.date, attribute: self.attribute)
            }
        case .remove:
            editor?.remove(self.attribute)
        }
        editor?.apply()
        self.attribute = ""
    }
}
