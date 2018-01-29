/* Copyright 2018 Urban Airship and Contributors */

import Foundation
import AirshipKit

class InboxDelegate : NSObject, UAInboxDelegate {

    var tabBarController : UITabBarController;
    var messageCenterViewController : MessageCenterViewController;

    init(rootViewController:UIViewController) {
        self.tabBarController = rootViewController as! UITabBarController
        self.messageCenterViewController = self.tabBarController.viewControllers![2] as! MessageCenterViewController;
    }
    
    func showInbox() {
        DispatchQueue.main.async {
            self.tabBarController.selectedIndex = 2
        }
    }

    func showMessage(forID messageID: String) {
        self.showInbox()
        self.messageCenterViewController.displayMessageForID(messageID)
    }
}


