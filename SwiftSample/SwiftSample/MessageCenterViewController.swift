/* Copyright Airship and Contributors */

import Foundation
import UIKit
import AirshipKit

class MessageCenterViewController : UAMessageCenterSplitViewController {

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        self.style = UAirship.messageCenter().style
    }

    func showInbox() {
        self.listViewController.navigationController?.popToRootViewController(animated: true)
    }
    
    func displayMessageForID(_ messageID: String) {
        self.listViewController.displayMessage(forID: messageID)
    }
}
