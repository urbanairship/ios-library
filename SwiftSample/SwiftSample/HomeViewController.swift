/*
Copyright 2009-2016 Urban Airship Inc. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

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

    func refreshView () {
        if (UAirship.push().userPushNotificationsEnabled) {
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
                let message = UAInAppMessage()
                message.alert = NSLocalizedString("UA_Copied_To_Clipboard", tableName: "UAPushUI", comment: "Copied to clipboard string")
                message.position = UAInAppMessagePosition.top
                message.duration = 1.5
                message.primaryColor = UIColor(red: 255/255, green: 200/255, blue: 40/255, alpha: 1)
                message.secondaryColor = UIColor(red: 0/255, green: 105/255, blue: 143/255, alpha: 1)

                UAirship.inAppMessaging().display(message)
            }
        }
    }
}

