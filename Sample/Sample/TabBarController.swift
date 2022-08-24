/* Copyright Airship and Contributors */

import UIKit
import SwiftUI
import AirshipDebug

class TabBarController: UITabBarController {
    #if DEBUG
    override func viewDidLoad() {
        super.viewDidLoad()

        let debugViewController = UIHostingController(
            rootView: AirshipDebugView()
        )
        
        // Debug library needs to operate in a nav controller
        let debugNavController = UINavigationController(rootViewController: debugViewController)
        
        // Create new tab bar item for debug library
        let debugTitle = NSLocalizedString("ua_debug_tab_title", tableName: "UAPushUI", comment: "Debug")
        let debugItem = UITabBarItem.init(title: debugTitle, image: UIImage.init(named: "outline_bug_report_black_36pt"), tag: 0)
        debugNavController.tabBarItem = debugItem
        
        // Add tab to tab bar
        viewControllers?.append(debugNavController)
    }
    #endif
}
