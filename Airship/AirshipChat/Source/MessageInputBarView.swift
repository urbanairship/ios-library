/* Copyright Airship and Contributors */

import UIKit

@available(iOS 13.0, *)
@objc(UAChatMessageInputBarView)
class MessageInputBarView: UIView {
    static let maxHeight: CGFloat = 125.0
    static let minHeight: CGFloat = 80.0
    static let paddingTop: CGFloat = 8.0
    static let paddingBottom: CGFloat = 8.0

    @IBOutlet weak var placeholder: UILabel!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var textViewHeight: NSLayoutConstraint!

    override var intrinsicContentSize: CGSize {
        let size = textViewContentSize()
        let totalHeight = size.height + MessageInputBarView.paddingTop + MessageInputBarView.paddingBottom

        // Allow the intrinsic size to grow up to the max height to accomodate an exapanding text view
        if totalHeight <= MessageInputBarView.maxHeight {
            return CGSize(width: self.bounds.width, height: max(totalHeight, MessageInputBarView.minHeight))
        } else {
            // Prevent further expansion and keep it at the max height
            return CGSize(width: self.bounds.width, height: MessageInputBarView.maxHeight)
        }
    }

    public func updateHeightConstraint() {
        let contentHeight = textViewContentSize().height
        let constrainedHeight = min(contentHeight, MessageInputBarView.maxHeight)

        textView.isScrollEnabled = contentHeight >= MessageInputBarView.maxHeight

        if textViewHeight.constant != constrainedHeight {
            textViewHeight.constant = constrainedHeight
            layoutIfNeeded()
        }
    }

    func textViewContentSize() -> CGSize {
        let size = CGSize(width: textView.bounds.width,
                          height: CGFloat.greatestFiniteMagnitude)

        let textSize = textView.sizeThatFits(size)
        return CGSize(width: bounds.width, height: textSize.height)
    }
}
