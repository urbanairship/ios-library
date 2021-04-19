/* Copyright Airship and Contributors */

import UIKit

@available(iOS 13.0, *)
@objc(UAChatMessageCell)
class ChatMessageCell: UITableViewCell {
    @IBOutlet weak var messageDateLabel: UILabel!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var messageTextLabel: UILabel!
}
