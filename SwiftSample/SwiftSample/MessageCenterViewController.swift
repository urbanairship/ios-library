/* Copyright Airship and Contributors */

import Foundation
import UIKit
import AirshipCore
import AirshipMessageCenter

class MessageCenterViewController : DefaultMessageCenterSplitViewController {

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.messageCenterStyle = MessageCenterStyle(contentsOfFile: "MessageCenterStyle")
    }
    
    func showInbox() {
        self.listViewController.navigationController?.popToRootViewController(animated: true)
    }
}
