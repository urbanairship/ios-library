/* Copyright Urban Airship and Contributors */

import UIKit

#if canImport(AirshipCore)
import AirshipCore
#elseif !COCOAPODS && canImport(Airship)
import Airship
#endif

/**
 * Chat view controller.
 */
@available(iOS 13.0, *)
@objc(UAChatViewController)
public class ChatViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextViewDelegate, ConversationDelegate {
    /**
     * Message draft.
     */
    @objc
    public var messageDraft: String? {
        didSet {
            self.textView?.text = messageDraft ?? ""
        }
    }
    
    @IBOutlet private var tableView: UITableView!
    @IBOutlet private var placeHolder: UILabel!
    @IBOutlet private var textView: UITextView!
    @IBOutlet private var sendButton: UIButton!
    @IBOutlet private var inputBar: UIView!

    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var textViewHeightConstraint: NSLayoutConstraint!

    private var textViewHeight: CGFloat!
    private var messages: Array<ChatMessage> = Array<ChatMessage>()

    /**
     * Message style.
     */
    @objc
    public var chatStyle: ChatStyle?

    public func onMessagesUpdated() {
        AirshipChat.shared().conversation.fetchMessages(completionHandler: { (messages) in
            self.messages = messages
            self.reload()
        })
    }

    public func onConnectionStatusChanged() {
        AirshipLogger.debug("Connection status changed: \(AirshipChat.shared().conversation.isConnected)")
    }

    public override var nibBundle: Bundle? {
        return ChatResources.bundle()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.textViewHeight = self.textView.bounds.size.height

        self.tableView.register(UINib(nibName: "ChatMessageCell", bundle: ChatResources.bundle()), forCellReuseIdentifier: "ChatMessageCell")

        if let prefill = self.messageDraft {
            self.textView.text = prefill
        }

        if chatStyle != nil {
            applyStyle(style: chatStyle!)
        }

        updatePlaceholder()
        resizeTextView()

        observeNotificationCenterEvents()
        setupGestureRecognizers()
        updatePlaceholder()

        self.textView.delegate = self
        self.sendButton.addTarget(self, action: #selector(sendMessage(sender:)), for: .touchUpInside)
        self.sendButton.setTitle(ChatResources.localizedString(key: "ua_chat_send_button"), for: .normal)

        tableView.delegate = self
        tableView.dataSource = self

        AirshipChat.shared().conversation.delegate = self

        onMessagesUpdated()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollToBottom(animated: false)
    }


    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let rows = messages.count
        return rows
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let message = messages[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "ChatMessageCell", for:indexPath) as! ChatMessageCell

        if (message.direction == .incoming) {
            cell.stackView.alignment = .leading
            cell.messageTextLabel.backgroundColor = chatStyle?.incomingChatBubbleColor ?? UIColor.systemGray6
            cell.containerView.backgroundColor = chatStyle?.incomingChatBubbleColor ?? UIColor.systemGray6
            cell.messageTextLabel.textColor = chatStyle?.incomingTextColor ?? cell.messageTextLabel.textColor
        } else {
            cell.stackView.alignment = .trailing
            cell.messageTextLabel.backgroundColor = chatStyle?.outgoingChatBubbleColor ?? UIColor.systemBlue
            cell.containerView.backgroundColor = chatStyle?.outgoingChatBubbleColor ?? UIColor.systemBlue
            cell.messageTextLabel.textColor = chatStyle?.outgoingTextColor ?? UIColor.systemGray6
        }

        cell.messageTextLabel.font = chatStyle?.messageTextFont ?? cell.messageTextLabel.font
        cell.messageTextLabel?.text = message.text

        cell.messageDateLabel.textColor = chatStyle?.dateColor ?? cell.messageDateLabel.textColor
        cell.messageDateLabel.font = chatStyle?.dateFont ?? cell.messageDateLabel.font

        if (message.isDelivered) {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            formatter.locale = UAirship.shared().locale.currentLocale
            cell.messageDateLabel?.text = formatter.string(from: message.timestamp)
        } else {
            // TODO: localization
            cell.messageDateLabel?.text = "Sending"
        }

        return cell
    }

    public func textViewDidEndEditing(_ textView: UITextView) {
        updatePlaceholder()
        resizeTextView()
    }

    public func textViewDidChange(_ textView: UITextView) {
        updatePlaceholder()
        resizeTextView()
    }

    func applyStyle(style: ChatStyle) {
        self.tableView.backgroundColor = style.backgroundColor ?? self.tableView.backgroundColor
        self.view.backgroundColor = style.backgroundColor ?? self.view.backgroundColor
        self.inputBar.backgroundColor = style.backgroundColor ?? self.inputBar.backgroundColor
        self.sendButton.tintColor = style.tintColor ?? self.sendButton.tintColor
    }

    func observeNotificationCenterEvents() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onKeyboardWillChangeFrame(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification,
                                               object: nil)
    }

    func setupGestureRecognizers() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(tappedTableView))
        self.tableView.addGestureRecognizer(tap)
    }

    @objc
    func onKeyboardWillChangeFrame(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo else {
            return
        }

        guard let frameEnd = userInfo[UIWindow.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        let bottomSpacing = self.view.frame.height + self.view.frame.origin.y - frameEnd.origin.y - self.view.safeAreaInsets.bottom
        self.bottomConstraint.constant = bottomSpacing > 0 ? -bottomSpacing : 0

        self.view.layoutIfNeeded()
    }

    @objc func swipedInputBar(gesture: UISwipeGestureRecognizer) {
        self.textView.resignFirstResponder()
    }

    @objc func tappedTableView(gesture: UISwipeGestureRecognizer) {
        if (gesture.state != .ended) {
            return
        }

        self.textView.resignFirstResponder()
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
        self.placeHolder.isHidden = self.textView.text?.isEmpty == false
    }

    @IBAction func sendMessage(sender: UIButton) {
        let inputText = self.textView.text

        if let message = inputText {
            if (!message.isEmpty) {
                AirshipChat.shared().conversation.sendMessage(message)
                self.textView.text = ""
            }
        }
        updatePlaceholder()
        resizeTextView()
    }

    private func resizeTextView() {
        textViewHeightConstraint.constant = min(120, max(self.textViewHeight, self.textView.contentSize.height))
    }
}
