/* Copyright Airship and Contributors */

import UIKit
import AirshipCore
import AirshipPreferenceCenter

class HomeViewController: UIViewController {

    @IBOutlet private weak var enablePushButton: UIButton!
    @IBOutlet private weak var channelIDButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(HomeViewController.refreshView),
            name: Channel.channelCreatedEvent,
            object: nil);
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshView()
    }

    @objc func refreshView () {
        if (checkNotificationsEnabled()) {
            channelIDButton.setTitle(Airship.channel.identifier, for: [])
            channelIDButton.isHidden = false
            enablePushButton.isHidden = true
            return
        }

        channelIDButton.isHidden = true
        enablePushButton.isHidden = false
    }

    @IBAction func buttonTapped(_ sender: UIButton) {
        if (sender == enablePushButton) {
            Airship.push.userPushNotificationsEnabled = true
            Airship.shared.privacyManager.enableFeatures(.push)
        }

        //The channel ID will need to wait for push registration to return the channel ID
        if (sender == channelIDButton) {
            if ((Airship.channel.identifier) != nil) {
                UIPasteboard.general.string = Airship.channel.identifier

                let message = NSLocalizedString("UA_Copied_To_Clipboard", tableName: "UAPushUI", comment: "Copied to clipboard string")

                let alert = UIAlertController(title: nil, message: message, preferredStyle: UIAlertController.Style.alert)
                let buttonTitle = NSLocalizedString("UA_OK", tableName: "UAPushUI", comment: "OK button string")

                let okAction = UIAlertAction(title: buttonTitle, style: UIAlertAction.Style.default, handler: { (action: UIAlertAction) in
                    self.dismiss(animated: true, completion: nil)
                })

                alert.addAction(okAction)

                self.present(alert, animated: true, completion: nil)
            }
        }

        refreshView()
    }

    func checkNotificationsEnabled() -> Bool {
        if (!Airship.push.userPushNotificationsEnabled) {
            return false
        }

        return Airship.shared.privacyManager.isEnabled(.push)
    }
}

