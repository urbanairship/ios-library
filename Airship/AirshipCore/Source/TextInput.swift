/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI

struct TextInput: View {
    let model: TextInputModel
    let constraints: ViewConstraints

    @Environment(\.sizeCategory) var sizeCategory
    @Environment(\.colorScheme) var colorScheme

    @EnvironmentObject var formState: FormState
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment

    @State private var input: String = ""
    @State private var isEditing: Bool = false
    
    #if !os(watchOS)
    private var keyboardType: UIKeyboardType {
        switch self.model.inputType {
        case .email:
            return .emailAddress
        case .number:
            return .decimalPad
        case .text:
            return .default
        case .textMultiline:
            return .default
        }
    }
    #endif
    
    @ViewBuilder
    private func createTextEditor() -> some View {
        let binding = Binding<String>(
            get: { self.input },
            set: {
                self.input = $0
                self.updateValue($0)
            }
        )

        if #available(iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
            AirshipTexField(
                model: self.model,
                constraints: constraints,
                binding: binding,
                isEditing: $isEditing
            )
        } else {
            // Fallback on earlier versions
            #if !os(watchOS)
            AirshipTextView(
                textAppearance: self.model.textAppearance,
                text: binding,
                isEditing: $isEditing
            )
            .constraints(constraints, alignment: .topLeading)
            .airshipOnChangeOf(self.isEditing) { newValue in
                let focusedID = newValue ? self.model.identifier : nil
                self.thomasEnvironment.focusedID = focusedID
            }
            #endif
        }
    }
    
    @ViewBuilder
    var body: some View {
        ZStack {
            if let hint = self.model.placeHolder {
                Text(hint)
                    .textAppearance(placeHolderTextAppearance())
                    .padding(5)
                    .constraints(constraints, alignment: .topLeading)
                    .opacity(input.isEmpty && !isEditing ? 1 : 0)
                    .animation(.linear(duration: 0.1), value: self.model.placeHolder)
            }
            createTextEditor()
                .id(self.model.identifier)
        }
        .background(
            color: self.model.backgroundColor,
            border: self.model.border
        )
        #if !os(watchOS)
        .keyboardType(keyboardType)
        #endif

        .common(self.model, formInputID: self.model.identifier)
        .accessible(self.model)
        .formElement()
        .onAppear {
            restoreFormState()
            updateValue(input)
        }
    }

    private func restoreFormState() {
        guard
            case let .text(value) = self.formState.data.formValue(
                identifier: self.model.identifier
            ),
            let value = value
        else {
            return
        }

        self.input = value
    }

    private func updateValue(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let isValid = !trimmed.isEmpty || !(self.model.isRequired ?? false)
        let data = FormInputData(
            self.model.identifier,
            value: .text(trimmed.isEmpty ? nil : trimmed),
            attributeName: self.model.attributeName,
            attributeValue: trimmed.isEmpty ? nil : .string(trimmed),
            isValid: isValid
        )
        self.formState.updateFormInput(data)
    }

    private func placeHolderTextAppearance() -> some BaseTextAppearance {
        guard let color = self.model.textAppearance.placeHolderColor else {
            return self.model.textAppearance
        }

        var appearance = self.model.textAppearance
        appearance.color = color
        return appearance
    }
}

@available(iOS 16.0, tvOS 16, watchOS 9.0, *)
struct AirshipTexField: View {
    
    let model: TextInputModel
    let constraints: ViewConstraints

    @Binding var binding: String
    @Binding var isEditing: Bool

    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment
    
    @FocusState private var focused: Bool

    var body: some View {
        let axis: Axis = self.model.inputType == .textMultiline ? .vertical : .horizontal
        TextField("", text: $binding, axis: axis)
            .padding(5)
            .airshipOnChangeOf( binding) { [binding] newValue in
                if (axis == .vertical) {
                    let oldCount = binding.filter { $0 == "\n" }.count
                    let newCount = newValue.filter { $0 == "\n" }.count

                    if (newCount == oldCount + 1) {
                        self.binding = binding
                        self.focused = false
                    }
                }
            }
            .constraints(constraints, alignment: .topLeading)
            .focused($focused)
            .foregroundColor(self.model.textAppearance.color.toColor(colorScheme))
            .contentShape(Rectangle())
            .onTapGesture {
                self.focused = true
            }
            .applyViewAppearance(self.model.textAppearance)
            .applyIf(isUnderlined, transform: { content in
                content.underline()
            })
            .airshipOnChangeOf( focused) { newValue in
                if (newValue) {
                    self.thomasEnvironment.focusedID = self.model.identifier
                } else if (self.thomasEnvironment.focusedID == self.model.identifier) {
                    self.thomasEnvironment.focusedID = nil
                }

                isEditing = newValue
            }
    }
    
    private var isUnderlined : Bool {
        if let styles = self.model.textAppearance.styles {
            if styles.contains(.underlined) {
                return true
            }
        }
        return false
    }
}


#if !os(watchOS)
/// TextView

internal struct AirshipTextView: UIViewRepresentable {
    let textAppearance: TextInputTextAppearance
    @Binding var text: String
    @Binding var isEditing: Bool

    @Environment(\.colorScheme) var colorScheme
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        /// Set textView background color to clear to can set the parent background color instead
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator

        #if os(iOS)
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let done = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: textView,
            action: #selector(textView.resignFirstResponder)
        )

        let flexSpace = UIBarButtonItem(
            barButtonSystemItem: .flexibleSpace,
            target: nil,
            action: nil
        )

        toolbar.items = [flexSpace, done]
        textView.inputAccessoryView = toolbar
        #endif

        textView.applyTextAppearance(self.textAppearance, colorScheme)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.applyTextAppearance(self.textAppearance, colorScheme)
        uiView.textModifyAppearance(self.textAppearance)
        if uiView.text.isEmpty && !self.text.isEmpty {
            uiView.text = self.text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator($text, isEditing: $isEditing)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        var isEditing: Binding<Bool>

        let subject = PassthroughSubject<String, Never>()
        let cancellable: Cancellable

        init(_ text: Binding<String>, isEditing: Binding<Bool>) {
            self.text = text
            self.isEditing = isEditing
            self.cancellable =
                subject
                .debounce(for: .seconds(0.2), scheduler: RunLoop.main)
                .sink {
                    text.wrappedValue = $0
                }
        }

        func textViewDidChange(_ textView: UITextView) {
            subject.send(textView.text)
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            self.isEditing.wrappedValue = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            self.isEditing.wrappedValue = false
        }
    }
}

extension UITextView {
    func applyTextAppearance<Appearance: BaseTextAppearance>(
        _ textAppearance: Appearance?,
        _ colorScheme: ColorScheme
    ) {
        if let textAppearance = textAppearance {
            self.textAlignment =
                textAppearance.alignment?.toNSTextAlignment() ?? .center
            self.textColor =
                textAppearance.color.toUIColor(colorScheme)
            self.font = UIFont.resolveUIFont(textAppearance)
        }
    }

    func textModifyAppearance<Appearance: BaseTextAppearance>(
        _ textAppearance: Appearance
    ) {
        underlineText(textAppearance)
    }

    func underlineText<Appearance: BaseTextAppearance>(
        _ textAppearance: Appearance
    ) {
        if let styles = textAppearance.styles {
            if styles.contains(.underlined) {
                let textRange = NSRange(
                    location: 0,
                    length: self.text.count
                )
                let attributeString = NSMutableAttributedString(
                    attributedString:
                        self.attributedText
                )
                attributeString.addAttribute(
                    .underlineStyle,
                    value: NSUnderlineStyle.single.rawValue,
                    range: textRange
                )
                self.attributedText = attributeString
            }
        }
    }
}
#endif
