/* Copyright Airship and Contributors */

import UIKit

// A text view that looks more like a big text field
class MultilineTextField : UITextView {
    private var placeholderTextView: UITextView = UITextView()

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    private func commonInit() {
        applyCommonTextViewAttributes(to: self)
        self.applyCupertinoBorder(#colorLiteral(red:204.0/255.0, green:204.0/255.0, blue:204.0/255.0, alpha: 1.0))
    }

    private func applyCommonTextViewAttributes(to textView: UITextView) {
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = UIEdgeInsets(top: 10,
                                                   left: 10,
                                                   bottom: 10,
                                                   right: 10)
    }
}
