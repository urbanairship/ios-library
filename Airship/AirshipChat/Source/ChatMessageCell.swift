/* Copyright Airship and Contributors */

import UIKit

@available(iOS 13.0, *)
@objc(UAChatMessageCell)
open class ChatMessageCell: UITableViewCell {
    @IBOutlet public weak var messageDateLabel: UILabel!
    @IBOutlet public weak var containerView: UIView!
    @IBOutlet public weak var stackView: UIStackView!
    @IBOutlet public weak var messageTextLabel: UILabel!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
