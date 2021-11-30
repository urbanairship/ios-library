/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Airship Text input
@available(iOS 13.0.0, tvOS 13.0, *)
struct AirshipTextInput : View {
    let model: TextInputModel
    @Binding var text: String
    var body: some View {
        TextView(model: model, text: $text)
            .formInput()
    }
}

/// TextView
@available(iOS 13.0.0, tvOS 13.0, *)
struct TextView: UIViewRepresentable {
    let model: TextInputModel
    @Binding var text: String

    @Environment(\.colorScheme) var colorScheme
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        /// Set textView background color to clear to can set the parent background color instead
        textView.backgroundColor = UIColor.clear
        textView.delegate = context.coordinator
        return textView.textAppearance(model.textAppearance, colorScheme)
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.textModifyAppearance(self.model.textAppearance)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator($text)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        
        init(_ text: Binding<String>) {
            self.text = text
        }
        
        func textViewDidChange(_ textView: UITextView) {
            self.text.wrappedValue = textView.text
        }
    }
}
