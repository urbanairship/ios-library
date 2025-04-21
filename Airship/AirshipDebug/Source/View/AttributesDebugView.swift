/* Copyright Urban Airship and Contributors */

import Foundation
public import SwiftUI

#if canImport(AirshipCore)
public import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

public struct AttributesDebugView: View {
    private let editorFactory: () -> AttributesEditor?

    private enum AttributeAction: String, Equatable, CaseIterable {
        case add = "Add"
        case remove = "Remove"
    }

    private enum AttributeType: String, Equatable, CaseIterable {
        case text = "Text"
        case number = "Number"
        case date = "Date"
        case json = "JSON"
    }

    public init(editorFactory: @escaping () -> AttributesEditor?) {
        self.editorFactory = editorFactory
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

    @State
    private var jsonText: String = ""

    @State
    private var instanceID: String = ""

    @State
    private var expiryEnabled: Bool = false

    @State
    private var expiryDate = Date()

    @ViewBuilder
    func makeValue() -> some View {
        switch self.type {
        case .date:
            #if os(tvOS)
            TVDatePicker(
                "Date".localized(),
                selection: $date,
                displayedComponents: .all
            )
            #else
            DatePicker(
                "Date".localized(),
                selection: $date,
                displayedComponents: [.date, .hourAndMinute]
            )
            #endif
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
        case .json:
            VStack(alignment: .leading, spacing: 8) {
                Text("JSON")
                Group {
                    #if !os(tvOS)
                    TextEditor(text: $jsonText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(height: 100)
                    #else
                    MultilineTextView(text: $jsonText)
                        .frame(height: 100)
                    #endif
                }.overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            jsonText.isEmpty || jsonIsValid
                            ? Color.secondary.opacity(0.5)
                            : Color.red
                        )
                )
                .onChange(of: jsonText) { newValue in
                    guard let data = newValue.data(using: .utf8) else { return }
                    do {
                        let obj = try JSONSerialization.jsonObject(with: data)
                        let prettyData = try JSONSerialization.data(
                            withJSONObject: obj,
                            options: .prettyPrinted
                        )
                        if let prettyString = String(data: prettyData, encoding: .utf8),
                           prettyString != newValue {
                            jsonText = prettyString
                        }
                    } catch {}
                }
                HStack {
                    Text("Instance ID")
                    Spacer()
                    TextField("ID".localized(), text: $instanceID.preventWhiteSpace())
                        .freeInput()
                }
                Toggle("Expiry".localized(), isOn: $expiryEnabled)
                if expiryEnabled {
                    #if os(tvOS)
                    TVDatePicker(
                        "Date".localized(),
                        selection: $expiryDate,
                        displayedComponents: .all
                    )
                    #else
                    DatePicker(
                        "Date".localized(),
                        selection: $expiryDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    #endif
                }
            }
        }
    }

    public var body: some View {
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
            case .json: return !jsonText.isEmpty && !instanceID.isEmpty
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
            case .json:
                do {
                    let root = try AirshipJSON.from(json: jsonText)

                    guard case let .object(dict) = root else {
                        throw AirshipErrors.error("Top‑level JSON must be an object")
                    }

                    if expiryEnabled {
                        try editor?.set(
                            json: dict,
                            attribute: attribute,
                            instanceID: instanceID,
                            expiration: expiryDate
                        )
                    } else {
                        try editor?.set(
                            json: dict,
                            attribute: attribute,
                            instanceID: instanceID
                        )
                    }
                } catch {
                    AirshipLogger.error("JSON attribute error: \(error)")
                }
            }
        case .remove:
            editor?.remove(self.attribute)
        }
        editor?.apply()
        attribute = ""
        text = ""
        number = 0
        jsonText = ""
        instanceID = ""
        expiryEnabled = false
        expiryDate = Date()
    }

    private var jsonIsValid: Bool {
        guard let data = jsonText.data(using: .utf8) else {
            return false
        }
        return (try? JSONSerialization.jsonObject(with: data, options: [])) != nil
    }
}

/// For tvOS
struct MultilineTextView: UIViewRepresentable {
    @Binding var text: String

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: MultilineTextView
        init(_ parent: MultilineTextView) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) { parent.text = textView.text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        tv.delegate = context.coordinator
        tv.textColor = .label
        tv.backgroundColor = .clear
        tv.isScrollEnabled = true
        tv.text = text
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text { uiView.text = text }
    }
}
