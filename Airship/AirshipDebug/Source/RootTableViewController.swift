/* Copyright Airship and Contributors */

import UIKit

class RootTableViewController: UITableViewController {
    let deviceInfoSegue = "deviceInfoSegue"
    let eventsSegue = "eventsSegue"
    let automationSegue = "automationSegue"
    let receivedPushesSegue = "receivedPushesSegue"
    
    @IBOutlet var deviceInfoTitle: UILabel!
    @IBOutlet var deviceInfoSubtitle: UILabel!
    @IBOutlet var deviceInfoCell: UITableViewCell!

    @IBOutlet var eventsTitle: UILabel!
    @IBOutlet var eventsSubtitle: UILabel!
    @IBOutlet var eventsCell: UITableViewCell!

    @IBOutlet var automationTitle: UILabel!
    @IBOutlet var automationSubtitle: UILabel!
    @IBOutlet var automationCell: UITableViewCell!
    
    @IBOutlet var receivedPushesTitle: UILabel!
    @IBOutlet var receivedPushesSubtitle: UILabel!
    @IBOutlet var receivedPushesCell: UITableViewCell!
    
    var deviceInfoViewController: DeviceInfoViewController?
    var eventsViewController: EventsViewController?
    var automationTableViewController: AutomationTableViewController?
    var receivedPushesViewController: PushNotificationsTableViewController?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        AirshipDebug.rootViewController = self
    }
    
    func setTableViewTheme() {
        tableView.backgroundColor = ThemeManager.shared.currentTheme.Background;
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor:ThemeManager.shared.currentTheme.NavigationBarText]
        navigationController?.navigationBar.barTintColor = ThemeManager.shared.currentTheme.NavigationBarBackground;
    }

    func localize() {
        navigationController?.navigationBar.topItem?.title = "ua_debug_title".localized()

        deviceInfoTitle.text = "ua_device_info_title".localized()
        deviceInfoSubtitle.text = "ua_device_info_subtitle".localized()
        eventsTitle.text = "ua_events_title".localized()
        eventsSubtitle.text = "ua_events_subtitle".localized()
        automationTitle.text = "ua_automation_title".localized()
        automationSubtitle.text = "ua_automation_subtitle".localized()
        receivedPushesTitle.text = "ua_received_pushes_title".localized()
        receivedPushesSubtitle.text = "ua_received_pushes_subtitle".localized()
    }

    func setCellTheme() {
        deviceInfoCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        deviceInfoTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        deviceInfoSubtitle.textColor = ThemeManager.shared.currentTheme.SecondaryText

        eventsCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        eventsTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        eventsSubtitle.textColor = ThemeManager.shared.currentTheme.SecondaryText

        automationCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        automationTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        automationSubtitle.textColor = ThemeManager.shared.currentTheme.SecondaryText

        receivedPushesCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        receivedPushesTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        receivedPushesSubtitle.textColor = ThemeManager.shared.currentTheme.SecondaryText

    }

    override func viewDidLoad() {
        super.viewDidLoad()

        localize()
        setTableViewTheme()
        setCellTheme()
    }
    
    func showView(_ launchPathComponents : [String]?) {
        guard var pathComponents = launchPathComponents else {
            self.navigationController?.popToRootViewController(animated: false)
            return
        }
        
        if (pathComponents.isEmpty) {
            self.navigationController?.popToRootViewController(animated: false)
            return
        }

        if (pathComponents[0] == "/") {
            pathComponents.remove(at: 0)
        }
        
        if (pathComponents.count == 0) {
            // navigating to the debug kit
            self.navigationController?.popToRootViewController(animated: false)
            return
        }
        
        // get storyboard name from first segment of deeplink
        let storyBoardName = pathComponents[0].lowercased()
        pathComponents.remove(at: 0)
 
        // map storyboard name to storyboard segue
        var segueIdentifier : String?
        switch (storyBoardName) {
        case AirshipDebug.deviceInfoViewName.lowercased():
            segueIdentifier = deviceInfoSegue
        case AirshipDebug.eventsViewName.lowercased() :
            segueIdentifier = eventsSegue
        case AirshipDebug.automationViewName.lowercased():
            segueIdentifier = automationSegue
        case AirshipDebug.receivedPushesViewName.lowercased():
            segueIdentifier = receivedPushesSegue
        default:
            break
        }
        
        // execute segue
        if let segueIdentifier = segueIdentifier {
            self.navigationController?.popToRootViewController(animated: false)
            self.performSegue(withIdentifier: segueIdentifier, sender: pathComponents)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Localize back button
        let backItem = UIBarButtonItem()
        backItem.title = "ua_debug_title".localized()
        navigationItem.backBarButtonItem = backItem

        // if this is a deep link, the components for the launch path
        // are encoded in the sender
        let launchPathComponents = sender as? [String]
        
        // save the view controller for future reference and handle deep links
        if let deviceInfoViewController = segue.destination as? DeviceInfoViewController {
            self.deviceInfoViewController = deviceInfoViewController
            deviceInfoViewController.launchPathComponents = launchPathComponents
        } else if let eventsViewController = segue.destination as? EventsViewController {
            self.eventsViewController = eventsViewController
            eventsViewController.launchPathComponents = launchPathComponents
        } else if let automationTableViewController = segue.destination as? AutomationTableViewController {
            self.automationTableViewController = automationTableViewController
            automationTableViewController.launchPathComponents = launchPathComponents
        } else if let receivedPushesViewController = segue.destination as? PushNotificationsTableViewController {
            self.receivedPushesViewController = receivedPushesViewController
            receivedPushesViewController.launchPathComponents = launchPathComponents
        }
    }
    
    func viewControllerForStoryboard(_ storyBoardName : String) -> UIViewController? {
        switch (storyBoardName) {
        case AirshipDebug.deviceInfoViewName.lowercased():
            if (self.deviceInfoViewController == nil) {
                self.deviceInfoViewController = AirshipDebug.instantiateViewControllerForStoryboard(storyBoardName) as? DeviceInfoViewController
            }
            return deviceInfoViewController
        case AirshipDebug.eventsViewName.lowercased() :
            if (self.eventsViewController == nil) {
                self.eventsViewController = AirshipDebug.instantiateViewControllerForStoryboard(storyBoardName) as? EventsViewController
            }
            return self.eventsViewController
        case AirshipDebug.automationViewName.lowercased():
            if (self.automationTableViewController == nil) {
                self.automationTableViewController = AirshipDebug.instantiateViewControllerForStoryboard(storyBoardName) as? AutomationTableViewController
            }
            return self.automationTableViewController
        case AirshipDebug.receivedPushesViewName.lowercased():
            if (self.receivedPushesViewController == nil) {
                self.receivedPushesViewController = AirshipDebug.instantiateViewControllerForStoryboard(storyBoardName) as? PushNotificationsTableViewController
            }
            return self.receivedPushesViewController
        default:
            return nil
        }
    }
}
