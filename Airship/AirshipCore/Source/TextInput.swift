/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

@available(iOS 13.0.0, tvOS 13.0, *)
struct TextInput : View {
    let model: TextInputModel
    let constraints: ViewConstraints
    
    @EnvironmentObject var formState: FormState
    @State private var input: String = ""
    @State private var isEditing: Bool = false

    @ViewBuilder
    private func createTextEditor() -> some View {
        let binding = Binding<String>(
            get: { self.input },
            set: { self.input = $0; self.updateValue($0) }
        )
        
#if !os(watchOS)
        AirshipTextView(textAppearance: self.model.textAppearance,
                         text: binding,
                         isEditing: $isEditing)
#endif
    }

    var body: some View {
        return ZStack {
            if let hint = self.model.placeHolder {
                Text(hint)
                    .textAppearance(placeHolderTextApperance())
                    .padding(EdgeInsets(top: 8, leading: 5, bottom: 0, trailing: 0 ))
                    .constraints(constraints, alignment:.topLeading)
                    .opacity(input.isEmpty && !isEditing ? 1 : 0)
                    .animation(.linear(duration: 0.1))
            }
            createTextEditor()
        }
        .constraints(constraints, alignment: .topLeading)
        .background(self.model.backgroundColor)
        .border(self.model.border)
        .common(self.model, formInputID: self.model.identifier)
        .accessible(self.model)
        .formElement()
        .onAppear {
            restoreFormState()
            updateValue(input)
        }
    }

    private func restoreFormState() {
        guard case let .text(value) = self.formState.data.formValue(identifier: self.model.identifier),
              let value = value
        else {
            return
        }

        self.input = value
    }
    
    private func updateValue(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let isValid = !trimmed.isEmpty || !(self.model.isRequired ?? false)
        let data = FormInputData(self.model.identifier,
                                 value: .text(trimmed.isEmpty ? nil : trimmed),
                                 isValid: isValid)
        self.formState.updateFormInput(data)
    }

    private func placeHolderTextApperance() -> some BaseTextAppearance {
        guard let color = self.model.textAppearance.placeHolderColor else {
            return self.model.textAppearance
        }

        var appearance = self.model.textAppearance
        appearance.color = color
        return appearance
    }
}

#if !os(watchOS)
/// TextView
@available(iOS 13.0.0, tvOS 13.0, *)
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

#if !os(tvOS)
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let done = UIBarButtonItem(barButtonSystemItem: .done,
                                   target: textView,
                                   action: #selector(textView.resignFirstResponder))

        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace,
                                        target: nil,
                                        action: nil)


        toolbar.items = [flexSpace, done]
        textView.inputAccessoryView = toolbar
#endif

        return textView.textAppearance(self.textAppearance, colorScheme)
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.textModifyAppearance(self.textAppearance)
        if (uiView.text.isEmpty && !self.text.isEmpty) {
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
            self.cancellable = subject
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
#endif
