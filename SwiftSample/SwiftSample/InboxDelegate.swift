/* Copyright 2010-2019 Urban Airship and Contributors */

import Foundation
import AirshipKit

class InboxDelegate : NSObject, UAInboxDelegate {

    var tabBarController : UITabBarController;
    var messageCenterViewController : MessageCenterViewController;

    init(rootViewController:UIViewController) {
        self.tabBarController = rootViewController as! UITabBarController
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        self.messageCenterViewController = self.tabBarController.viewControllers![appDelegate.MessageCenterTab] as! MessageCenterViewController;
    }

    func showInbox() {
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            self.tabBarController.selectedIndex = appDelegate.MessageCenterTab
        }
    }

    func showMessage(forID messageID: String) {
        self.showInbox()
        self.messageCenterViewController.displayMessageForID(messageID)
    }
}


