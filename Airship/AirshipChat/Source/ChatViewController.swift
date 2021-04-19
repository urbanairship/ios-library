/* Copyright Urban Airship and Contributors */

import UIKit

#if canImport(AirshipCore)
import AirshipCore
#elseif !COCOAPODS && canImport(Airship)
import Airship
#endif

@available(iOS 13.0, *)
@objc(UAChatViewController)
class ChatViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextViewDelegate, ConversationDelegate {
    final var message: String?
    
    @IBOutlet private var tableView: UITableView!

    private var messages: Array<ChatMessage> = Array<ChatMessage>()
    private var messageInputBarView: MessageInputBarView?

    func onMessagesUpdated() {
        AirshipChat.shared().conversation.fetchMessages(completionHandler: { (messages) in
            self.messages = messages
            self.reload()
        })
    }

    func onConnectionStatusChanged() {
        AirshipLogger.debug("Connection status changed: \(AirshipChat.shared().conversation.isConnected)")
    }

    // Provide the message input var view as an accessory, tying it to the keyboard
    override var inputAccessoryView: UIView? {
        get {
            return messageInputBarView
        }
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override var canResignFirstResponder: Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.register(UINib(nibName: "ChatMessageCell", bundle: Resources.bundle()), forCellReuseIdentifier: "ChatMessageCell")

        if (messageInputBarView == nil) {
            let bundle = Resources.bundle()!
            messageInputBarView = bundle.loadNibNamed("MessageInputBarView", owner: self, options: nil)!.first as? MessageInputBarView
        }

        if let prefill = message {
            self.messageInputBarView!.textView.text = prefill
        }

        observeNotficationCenterEvents()
        setupGestureRecognizers()
        updatePlaceholder()

        messageInputBarView!.textView.delegate = self
        messageInputBarView!.sendButton.addTarget(self, action: #selector(sendMessage(sender:)), for: .touchUpInside)

        tableView.delegate = self
        tableView.dataSource = self

        // TODO: styles

        AirshipChat.shared().conversation.delegate = self

        onMessagesUpdated()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollToBottom(animated: false)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let rows = messages.count
        return rows
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let message = messages[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "ChatMessageCell", for:indexPath) as! ChatMessageCell

        if (message.direction == .incoming) {
            cell.stackView.alignment = .leading
            cell.messageTextLabel.backgroundColor = UIColor.systemGray6
            cell.containerView.backgroundColor = UIColor.systemGray6
        } else {
            cell.stackView.alignment = .trailing
            cell.messageTextLabel.backgroundColor = UIColor.systemBlue
            cell.containerView.backgroundColor = UIColor.systemBlue
            cell.messageTextLabel.textColor = UIColor.systemGray6
        }

        cell.messageTextLabel?.text = message.text

        // TODO: styles

        if (message.isDelivered) {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            formatter.locale = UAirship.shared().locale.currentLocale
            cell.messageDateLabel?.text = formatter.string(from: message.timestamp)
        } else {
            cell.messageDateLabel?.text = "Sending"
        }

        return cell
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        updatePlaceholder()
    }

    func textViewDidChange(_ textView: UITextView) {
        updatePlaceholder()
        messageInputBarView?.updateHeightConstraint()
    }

    func observeNotficationCenterEvents() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillShow(_:)),
                                               name: UIResponder.keyboardWillShowNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillHide(_:)),
                                               name: UIResponder.keyboardWillHideNotification,
                                               object: nil)
    }

    func setupGestureRecognizers() {
        let gesture = UISwipeGestureRecognizer(target: self, action: #selector(swipedInputBar))
        gesture.direction = .down
        self.messageInputBarView!.textView.addGestureRecognizer(gesture)
    }

    @objc func keyboardWillShow(_ notification: NSNotification) {
        adjustForKeyboard(shown: true, notification: notification)
    }

    @objc func keyboardWillHide(_ notification: NSNotification) {
        adjustForKeyboard(shown: false, notification: notification)
    }

    @objc func swipedInputBar(gesture: UISwipeGestureRecognizer) {
        self.messageInputBarView!.textView.resignFirstResponder()
    }

    // Adjust content insets for the tableview to accomodate the onscreen keyboard
    func adjustForKeyboard(shown: Bool, notification: NSNotification) {
        guard notification.name == UIResponder.keyboardWillShowNotification || notification.name == UIResponder.keyboardWillChangeFrameNotification || notification.name == UIResponder.keyboardWillHideNotification else {
            return
        }

        let userInfo = notification.userInfo!
        let frameEnd = userInfo[UIWindow.keyboardFrameEndUserInfoKey] as! CGRect
        let duration = userInfo[UIWindow.keyboardAnimationDurationUserInfoKey] as! Double

        let bottomPadding:CGFloat = 30
        let accessoryHeight = messageInputBarView!.bounds.size.height

        let inputHeight = shown ? frameEnd.size.height + bottomPadding : accessoryHeight + bottomPadding

        if tableView.contentInset.bottom == inputHeight {
            return
        }

        let distanceFromBottom = bottomOffset().y - tableView.contentOffset.y

        var insets = tableView.contentInset
        insets.bottom = inputHeight

        UIView.animate(withDuration: duration, delay: 0, options:.curveEaseInOut, animations: {

            self.tableView.contentInset = insets
            self.tableView.scrollIndicatorInsets = insets

            if distanceFromBottom < 10 {
                self.tableView.contentOffset = self.bottomOffset()
            }
        }, completion: nil)
    }

    func reload() {
        tableView.reloadData()

        // Recompute layout so that sizes are correct
        tableView.invalidateIntrinsicContentSize()
        tableView.layoutIfNeeded()

        scrollToBottom(animated: false)
    }

    func scrollToBottom(animated: Bool) {
        view.layoutIfNeeded()
        let offset = bottomOffset()
        tableView.setContentOffset(offset, animated: animated)
    }

    func bottomOffset() -> CGPoint {
        return CGPoint(x: 0, y: max(-tableView.contentInset.top, tableView.contentSize.height - (tableView.bounds.size.height - tableView.contentInset.bottom)))
    }

    func updatePlaceholder() {
        if !messageInputBarView!.textView.hasText || messageInputBarView!.textView.text.isEmpty {
            messageInputBarView!.placeholder?.isHidden = false
        } else {
            messageInputBarView!.placeholder?.isHidden = true
        }
    }

    @IBAction func sendMessage(sender: UIButton) {
        let inputText = messageInputBarView!.textView.text

        if let message = inputText {
            if (!message.isEmpty) {
                AirshipChat.shared().conversation.send(message)
                messageInputBarView!.textView.text = ""

                // Resize the input bar in case the text view has expanded
                messageInputBarView?.invalidateIntrinsicContentSize()
                messageInputBarView?.updateHeightConstraint()
            }
        }
    }
}
