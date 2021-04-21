/* Copyright Urban Airship and Contributors */

import UIKit

#if canImport(AirshipCore)
import AirshipCore
#elseif !COCOAPODS && canImport(Airship)
import Airship
#endif

@available(iOS 13.0, *)
@objc(UAChatViewController)
public class ChatViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextViewDelegate, ConversationDelegate {
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

        updatePlaceholder()
        resizeTextView()

        observeNotficationCenterEvents()
        setupGestureRecognizers()
        updatePlaceholder()

        self.textView.delegate = self
        self.sendButton.addTarget(self, action: #selector(sendMessage(sender:)), for: .touchUpInside)

        tableView.delegate = self
        tableView.dataSource = self

        // TODO: styles

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

    public func textViewDidEndEditing(_ textView: UITextView) {
        updatePlaceholder()
        resizeTextView()
    }

    public func textViewDidChange(_ textView: UITextView) {
        updatePlaceholder()
        resizeTextView()
    }


    func observeNotficationCenterEvents() {
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
                AirshipChat.shared().conversation.send(message)
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
