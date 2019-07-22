/* Copyright Airship and Contributors */

import UIKit
import AirshipKit

class HomeViewController: UIViewController {

    @IBOutlet private weak var enablePushButton: UIButton!
    @IBOutlet private weak var channelIDButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(HomeViewController.refreshView),
            name: NSNotification.Name(UAChannelUpdatedEvent),
            object: nil);
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshView()
    }

    @objc func refreshView () {
        if (UAirship.shared() != nil && UAirship.push().userPushNotificationsEnabled) {
            channelIDButton.setTitle(UAirship.channel()?.identifier, for: [])
            channelIDButton.isHidden = false
            enablePushButton.isHidden = true
            return
        }
        channelIDButton.isHidden = true
        enablePushButton.isHidden = false
    }

    @IBAction func buttonTapped(_ sender: UIButton) {

        if (sender == enablePushButton) {
            UAirship.push().userPushNotificationsEnabled = true
        }

        //The channel ID will need to wait for push registration to return the channel ID
        if (sender == channelIDButton) {
            if ((UAirship.channel()?.identifier) != nil) {
                UIPasteboard.general.string = UAirship.channel()?.identifier

                let message = NSLocalizedString("UA_Copied_To_Clipboard", tableName: "UAPushUI", comment: "Copied to clipboard string")

                let alert = UIAlertController(title: nil, message: message, preferredStyle: UIAlertControllerStyle.alert)
                let buttonTitle = NSLocalizedString("UA_OK", tableName: "UAPushUI", comment: "OK button string")

                let okAction = UIAlertAction(title: buttonTitle, style: UIAlertActionStyle.default, handler: { (action: UIAlertAction) in
                    self.dismiss(animated: true, completion: nil)
                })

                alert.addAction(okAction)

                self.present(alert, animated: true, completion: nil)
            }
        }
    }
}

