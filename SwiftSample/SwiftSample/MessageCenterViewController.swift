/* Copyright Airship and Contributors */

import Foundation
import UIKit
import Airship

class MessageCenterViewController : UAMessageCenterSplitViewController {

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.style = UAMessageCenterStyle(contentsOfFile: "MessageCenterStyle")
    }

    func display() {
        self.listViewController.navigationController?.popToRootViewController(animated: true)
    }
    
    func displayMessageForID(_ messageID: String) {
        self.listViewController.displayMessage(forID: messageID)
    }
}
