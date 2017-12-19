/* Copyright 2017 Urban Airship and Contributors */

import UIKit
import AirshipKit

class HomeViewController: UIViewController {

    @IBOutlet var enablePushButton: UIButton!
    @IBOutlet var channelIDButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(HomeViewController.refreshView),
            name: NSNotification.Name("channelIDUpdated"),
            object: nil);
    }

    override func viewWillAppear(_ animated: Bool) {
        refreshView()
    }

    @objc func refreshView () {
        if (UAirship.shared() != nil && UAirship.push().userPushNotificationsEnabled) {
            channelIDButton.setTitle(UAirship.push().channelID, for: [])
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
            if ((UAirship.push().channelID) != nil) {
                UIPasteboard.general.string = UAirship.push().channelID
                // TODO: Replace this
                /*
                let message = UALegacyInAppMessage()
                message.alert = NSLocalizedString("UA_Copied_To_Clipboard", tableName: "UAPushUI", comment: "Copied to clipboard string")
                message.position = UALegacyInAppMessagePosition.top
                message.duration = 1.5
                message.primaryColor = UIColor(red: 255/255, green: 200/255, blue: 40/255, alpha: 1)
                message.secondaryColor = UIColor(red: 0/255, green: 105/255, blue: 143/255, alpha: 1)

                UAirship.inAppMessaging().display(message)
                */
            }
        }
    }
}

