/* Copyright Airship and Contributors */

import Foundation
import UIKit
import AirshipKit

class MessageCenterViewController : UAMessageCenterSplitViewController {

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        self.style = UAMessageCenter.shared().style

        // Match style of iOS Mail app
        self.style.cellTitleHighlightedColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
    }

    func displayMessageForID(_ messageID: String) {
        self.listViewController.displayMessage(forID: messageID)
    }
}
