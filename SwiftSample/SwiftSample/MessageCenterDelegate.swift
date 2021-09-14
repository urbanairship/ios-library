/* Copyright Airship and Contributors */

import Foundation
import AirshipCore
import AirshipMessageCenter

class MessageCenterDelegate : NSObject, MessageCenterDisplayDelegate {
    var tabBarController : UITabBarController;
    var messageCenterViewController : MessageCenterViewController;

    init(tabBarController:UITabBarController) {
        self.tabBarController = tabBarController
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        self.messageCenterViewController = self.tabBarController.viewControllers![appDelegate.MessageCenterTab] as! MessageCenterViewController;
    }

    func displayMessageCenter(forMessageID messageID: String, animated: Bool) {
        self.displayMessageCenter(animated: animated)
        DispatchQueue.main.async {
            self.messageCenterViewController.displayMessage(forID: messageID)
        }
    }

    func displayMessageCenter(animated: Bool) {
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            self.tabBarController.selectedIndex = appDelegate.MessageCenterTab
            self.messageCenterViewController.showInbox()
        }
    }

    func dismissMessageCenter(animated: Bool) {
        // no-op
    }
}


