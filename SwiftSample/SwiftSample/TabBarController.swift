/* Copyright Airship and Contributors */

import UIKit

class TabBarController: UITabBarController {
    #if DEBUG
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Instantiate debug library and add it to the tab bar
        
        // Instantiate debug library storyboard
        let debugStoryboard = UIStoryboard(name: "AirshipDebug", bundle:Bundle.init(identifier: "com.urbanairship.AirshipDebug"))
            
        // Instantiate debug library's initial view controller
        guard let debugViewController = debugStoryboard.instantiateInitialViewController() else { return }
        
        // Debug library needs to operate in a nav controller
        let debugNavController = UINavigationController.init(rootViewController: debugViewController)
        
        // Create new tab bar item for debug library
        let debugItem = UITabBarItem.init(title: "Debug", image: UIImage.init(named: "outline_bug_report_black_36pt"), tag: 0)
        debugNavController.tabBarItem = debugItem
        
        // Add tab to tab bar
        viewControllers?.append(debugNavController)
    }
    #endif
}
