/* Copyright Airship and Contributors */

import Foundation
import AirshipKit

class InboxDelegate : NSObject, UAInboxDelegate {

    var tabBarController : UITabBarController;
    var messageCenterViewController : MessageCenterViewController;

    init(tabBarController:UITabBarController) {
        self.tabBarController = tabBarController
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        self.messageCenterViewController = self.tabBarController.viewControllers![appDelegate.MessageCenterTab] as! MessageCenterViewController;
    }

    func showInbox() {
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            self.tabBarController.selectedIndex = appDelegate.MessageCenterTab
            self.messageCenterViewController.showInbox()
        }
    }

    func showMessage(forID messageID: String) {
        self.showInbox()
        DispatchQueue.main.async {
            self.messageCenterViewController.displayMessageForID(messageID)
        }
    }
}


