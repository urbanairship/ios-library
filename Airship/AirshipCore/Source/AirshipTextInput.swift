/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

#if !os(watchOS)

/// Airship Text input
@available(iOS 13.0.0, tvOS 13.0, *)
struct AirshipTextInput : View {
    let model: TextInputModel
    @Binding var text: String
    @Binding var isEditing: Bool
    var body: some View {
        TextView(model: model, text: $text, isEditing: $isEditing)
            .formInput()
    }
}

/// TextView
@available(iOS 13.0.0, tvOS 13.0, *)
struct TextView: UIViewRepresentable {
    let model: TextInputModel
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

        return textView.textAppearance(model.textAppearance, colorScheme)
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.textModifyAppearance(self.model.textAppearance)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator($text, isEditing: $isEditing)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        var isEditing: Binding<Bool>
        
        init(_ text: Binding<String>, isEditing: Binding<Bool>) {
            self.text = text
            self.isEditing = isEditing
        }
        
        func textViewDidChange(_ textView: UITextView) {
            self.text.wrappedValue = textView.text
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            self.isEditing.wrappedValue = true
        }

        func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
            self.isEditing.wrappedValue = false
            return true
        }
    }
}
#endif
