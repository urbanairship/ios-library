/* Copyright Urban Airship and Contributors */

import UIKit

class RootTableViewController: UITableViewController {
    let deviceInfoSegue = "deviceInfoSegue"
    let eventsSegue = "eventsSegue"
    let automationSegue = "automationSegue"
    
    @IBOutlet var deviceInfoTitle: UILabel!
    @IBOutlet var deviceInfoSubtitle: UILabel!
    @IBOutlet var deviceInfoCell: UITableViewCell!

    @IBOutlet var eventsTitle: UILabel!
    @IBOutlet var eventsSubtitle: UILabel!
    @IBOutlet var eventsCell: UITableViewCell!

    @IBOutlet var automationTitle: UILabel!
    @IBOutlet var automationSubtitle: UILabel!
    @IBOutlet var automationCell: UITableViewCell!
    
    var deviceInfoViewController: DeviceInfoViewController?
    var eventsViewController: EventsViewController?
    var automationTableViewController: AutomationTableViewController?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        AirshipDebugKit.rootViewController = self
    }
    
    func setTableViewTheme() {
        tableView.backgroundColor = ThemeManager.shared.currentTheme.Background;
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor:ThemeManager.shared.currentTheme.PrimaryText]
        navigationController?.navigationBar.barTintColor = ThemeManager.shared.currentTheme.NavigationBarBackground;
    }

    func localize() {
        navigationController?.navigationBar.topItem?.title = "ua_debug_kit_title".localized()

        deviceInfoTitle.text = "ua_device_info_title".localized()
        deviceInfoSubtitle.text = "ua_device_info_subtitle".localized()
        eventsTitle.text = "ua_events_title".localized()
        eventsSubtitle.text = "ua_events_subtitle".localized()
        automationTitle.text = "ua_automation_title".localized()
        automationSubtitle.text = "ua_automation_subtitle".localized()
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

    }

    override func viewDidLoad() {
        super.viewDidLoad()

        localize()
        setTableViewTheme()
        setCellTheme()
    }
    
    func showView(_ viewPath: URL) {
        var pathComponents = viewPath.pathComponents
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
        case AirshipDebugKit.deviceInfoViewName.lowercased():
            segueIdentifier = deviceInfoSegue
        case AirshipDebugKit.eventsViewName.lowercased() :
            segueIdentifier = eventsSegue
        case AirshipDebugKit.automationViewName.lowercased():
            segueIdentifier = automationSegue
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
        backItem.title = "ua_debug_kit_title".localized()
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
        }
    }
    
    func viewControllerForStoryboard(_ storyBoardName : String) -> UIViewController? {
        switch (storyBoardName) {
        case AirshipDebugKit.deviceInfoViewName.lowercased():
            if (self.deviceInfoViewController == nil) {
                self.deviceInfoViewController = AirshipDebugKit.instantiateViewControllerForStoryboard(storyBoardName) as? DeviceInfoViewController
            }
            return deviceInfoViewController
        case AirshipDebugKit.eventsViewName.lowercased() :
            if (self.eventsViewController == nil) {
                self.eventsViewController = AirshipDebugKit.instantiateViewControllerForStoryboard(storyBoardName) as? EventsViewController
            }
            return self.eventsViewController
        case AirshipDebugKit.automationViewName.lowercased():
            if (self.automationTableViewController == nil) {
                self.automationTableViewController = AirshipDebugKit.instantiateViewControllerForStoryboard(storyBoardName) as? AutomationTableViewController
            }
            return self.automationTableViewController
        default:
            return nil
        }
    }
}
