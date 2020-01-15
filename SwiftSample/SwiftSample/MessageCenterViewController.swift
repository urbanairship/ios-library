/* Copyright Airship and Contributors */

import Foundation
import UIKit
import AirshipCore
import AirshipMessageCenter

class MessageCenterViewController : UADefaultMessageCenterSplitViewController {

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.style = UAMessageCenterStyle(contentsOfFile: "MessageCenterStyle")
    }
    
    func showInbox() {
        self.listViewController.navigationController?.popToRootViewController(animated: true)
    }
}
