/* Copyright Airship and Contributors */

import UIKit


#if canImport(AirshipCore)
import AirshipCore
import AirshipAutomation
import AirshipMessageCenter
import AirshipLocation
#elseif canImport(Airship)
import Airship
#endif


class SettingsCell: UITableViewCell {
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var subtitle: UILabel!
    @IBOutlet weak var cellSwitch: UISwitch!

    @IBOutlet var titleTopConstraint: NSLayoutConstraint!

    override func layoutSubviews() {
        super.layoutSubviews()

        guard let sub = subtitle.text else {
            return
        }

        if sub.isEmpty {
            titleTopConstraint.priority = UILayoutPriority(rawValue: 100)
        } else {
            titleTopConstraint.priority = UILayoutPriority(rawValue: 999)
        }

        layoutIfNeeded()
    }
    
}

class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @objc public static var tagsViewName = "tags"
    let tagsSegue = "tagsSegue"

    var launchPathComponents : [String]? {
        didSet {
            if (self.viewIfLoaded?.window != nil && self === self.navigationController?.visibleViewController) {
                segueToDeepLink();
            } else if (!(self  === self.navigationController?.visibleViewController))  {
                self.navigationController?.popToRootViewController(animated: false);
            }
        }
    }
    var launchCompletionHandler : (() -> Void)?

    private let localizedNone =  "ua_none".localized(comment: "None")
    private let sectionCount = 4
    
    @IBOutlet private var tableView: UITableView!

    /* Section
     * Note: Number of sections and sections for row are defined in their respective
     * table view data source methods
     */
    let pushSettings = 0,
    deviceSettings = 1,
    locationSettings = 2,
    analyticsSettings = 3

    // Push settings
    private let pushEnabled = IndexPath(row: 0, section: 0)
    
    // Device settings
    private let channelID = IndexPath(row: 0, section: 1),
    namedUser = IndexPath(row: 1, section: 1),
    tags = IndexPath(row: 2, section: 1)

    // Location settings
    private let locationEnabled = IndexPath(row: 0, section: 2)

    // Analytics settigns
    private let analyticsEnabled = IndexPath(row: 0, section: 3)
    
    @objc func pushSettingsButtonTapped(sender:Any) {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:],completionHandler: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let image = UIImage(named: "outline_settings_black_24pt")

        let pushSettings: UIBarButtonItem = UIBarButtonItem(image:image, style:.done, target: self, action: #selector(pushSettingsButtonTapped))
        self.navigationItem.rightBarButtonItem = pushSettings

        tableView.dataSource = self
        tableView.delegate = self
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(SettingsViewController.refreshView),
            name: Channel.channelCreatedEvent,
            object: nil);
        
        // add observer to didBecomeActive to update upon retrun from system settings screen
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(SettingsViewController.didBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil)
    }

    func setTableViewTheme() {
        tableView.backgroundColor = #colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1)
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor:#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1)]
        navigationController?.navigationBar.barTintColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1);
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated);
        segueToDeepLink()
    }
    
    func segueToDeepLink() {
        if let launchPathComponents = launchPathComponents {
            self.launchPathComponents = nil
            if (launchPathComponents.count > 0) {
                switch (launchPathComponents[0]) {
                case "tags":
                    performSegue(withIdentifier: tagsSegue, sender: self)
                default:
                    break
                }
            }
        }
        if let launchCompletionHandler = launchCompletionHandler {
            launchCompletionHandler()
        }
    }
    
    // this is necessary to update the view when returning from the system settings screen
    @objc func didBecomeActive() {
        refreshView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshView()
        setTableViewTheme()
    }
    
    @objc func refreshView() {
        tableView.reloadData()
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return sectionCount
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case pushSettings:
            return "ua_device_info_push_settings".localized(comment: "Push Settings")
        case deviceSettings:
            return "ua_device_info_device_settings".localized(comment: "Device Settings")
        case analyticsSettings:
            return "ua_device_info_analytics_settings".localized(comment: "Analytics")
        case locationSettings:
            return "ua_device_info_enable_location_enabled".localized(comment: "Location Enabled")
        default:
            return ""
        }
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerView = view as? UITableViewHeaderFooterView {
            headerView.textLabel?.textColor = #colorLiteral(red: 0, green: 0.2950756848, blue: 0.9987069964, alpha: 1)
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case pushSettings:
            return 1
        case deviceSettings:
            return 3
        case analyticsSettings:
            return 1
        case locationSettings:
            return 1
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell:SettingsCell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath) as! SettingsCell

        cell.backgroundColor = #colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1)
        cell.title.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        cell.subtitle?.textColor = #colorLiteral(red: 0.513617754, green: 0.5134617686, blue: 0.529979229, alpha: 1)
        cell.cellSwitch.onTintColor = #colorLiteral(red: 0, green: 0.2941176471, blue: 1, alpha: 1)
        cell.cellSwitch.tintColor = #colorLiteral(red: 0, green: 0.2950756848, blue: 0.9987069964, alpha: 1)

        // Cell switch, stepper and disclosure indicator are hidden by default
        cell.cellSwitch.isHidden = true

        // Cells will do the switching
        cell.cellSwitch.isUserInteractionEnabled = false
        cell.accessoryType = .none
        cell.subtitle.text = nil

        switch indexPath {
        case pushEnabled:
            cell.title.text = "ua_device_info_push_settings".localized(comment: "Push Settings")
            cell.subtitle.text = "ua_device_info_enable_push".localized(comment: "Enable Push")
            cell.cellSwitch.isHidden = false
            cell.cellSwitch.isOn = UAirship.push()?.userPushNotificationsEnabled ?? false
            cell.subtitle?.text = pushTypeString()
            cell.subtitle?.adjustsFontSizeToFitWidth = true;
            cell.subtitle?.minimumScaleFactor = 0.25;
            cell.subtitle?.numberOfLines = 1;
        case channelID:
            cell.title.text = "ua_device_info_channel_id".localized(comment: "Channel ID")
            cell.subtitle.text = UAirship.channel().identifier
        case namedUser:
            cell.title.text = "ua_device_info_named_user".localized(comment: "Named User")
            cell.subtitle?.text = UAirship.namedUser().identifier == nil ? localizedNone : UAirship.namedUser().identifier
            cell.accessoryType = .disclosureIndicator
        case tags:
            cell.title.text = "ua_device_info_tags".localized(comment: "Tags")
            if (UAirship.channel().tags.count > 0) {
                cell.subtitle?.text = UAirship.channel().tags.joined(separator: ", ")
            } else {
                cell.subtitle?.text = localizedNone
            }

            cell.accessoryType = .disclosureIndicator
        case analyticsEnabled:
            cell.title.text = "ua_device_info_analytics_enabled".localized(comment: "Analytics Enabled")
            cell.subtitle?.text = "ua_device_info_enable_analytics_tracking".localized(comment: "Enable analytics tracking")

            cell.cellSwitch.isHidden = false
            cell.cellSwitch.isOn = UAirship.shared().privacyManager.isEnabled(UAFeatures.analytics)
        case locationEnabled:
            cell.title.text = "ua_device_info_location_settings".localized(comment: "Location Settings")

            cell.cellSwitch.isHidden = false
            cell.cellSwitch.isOn = UAirship.shared().privacyManager.isEnabled(UAFeatures.location)

            let optedInToLocation = UALocation.shared().isLocationOptedIn()

            if (UAirship.shared().privacyManager.isEnabled(UAFeatures.location) && !optedInToLocation) {
                cell.subtitle?.text = "ua_location_enabled_detail".localized(comment: "Enable GPS and WIFI Based Location detail label") + " - NOT OPTED IN"
            } else {
                cell.subtitle?.text = localizedNone
            }
        default:
            break
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath) as! SettingsCell

        switch indexPath {
        case pushEnabled:
            cell.cellSwitch.setOn(!cell.cellSwitch.isOn, animated: true)
            if (cell.cellSwitch.isOn) {
                UAirship.push().userPushNotificationsEnabled = true
                UAirship.shared().privacyManager.enableFeatures(.push)
            } else {
                UAirship.push().userPushNotificationsEnabled = false
                UAirship.shared().privacyManager.disableFeatures(.push)
            }

        case channelID:
            if (UAirship.channel().identifier != nil) {
                UIPasteboard.general.string = cell.subtitle?.text
                showCopiedAlert()
            }
        case namedUser:
            performSegue(withIdentifier: "namedUserSegue", sender: self)
        case tags:
            performSegue(withIdentifier: "tagsSegue", sender: self)
        case analyticsEnabled:
            cell.cellSwitch.setOn(!cell.cellSwitch.isOn, animated: true)
            if (cell.cellSwitch.isOn) {
                UAirship.shared().privacyManager.enableFeatures(UAFeatures.analytics)
            } else {
                UAirship.shared().privacyManager.disableFeatures(UAFeatures.analytics)
            }
        case locationEnabled:
            cell.cellSwitch.setOn(!cell.cellSwitch.isOn, animated: true)
            if (cell.cellSwitch.isOn) {
                UAirship.shared().privacyManager.enableFeatures(UAFeatures.location)
                UALocation.shared().isLocationUpdatesEnabled = true
            } else {
                UAirship.shared().privacyManager.disableFeatures(UAFeatures.location)
                UALocation.shared().isLocationUpdatesEnabled = false
            }
        default:
            break
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func showCopiedAlert() {
        DispatchQueue.main.async {
            let message = "ua_copied_to_clipboard".localized(comment: "Copied to clipboard string")

            let alert = UIAlertController(title: nil, message: message, preferredStyle: UIAlertController.Style.alert)
            let buttonTitle = "UA_OK".localized(comment: "OK")

            let okAction = UIAlertAction(title: buttonTitle, style: UIAlertAction.Style.default, handler: { (action: UIAlertAction) in
                self.dismiss(animated: true, completion: nil)
            })

            alert.addAction(okAction)

            self.present(alert, animated: true, completion: nil)
        }
    }

    func pushTypeString () -> String {

        let authorizedSettings = UAirship.push().authorizedNotificationSettings;

        var settingsArray: [String] = []

        if (authorizedSettings.contains(.alert)) {
            settingsArray.append("ua_notification_type_alerts".localized(comment: "Alerts"))
        }

        if (authorizedSettings.contains(.badge)){
            settingsArray.append("ua_notification_type_badges".localized(comment: "Badges"))
        }

        if (authorizedSettings.contains(.sound)) {
            settingsArray.append("ua_notification_type_sounds".localized(comment: "Sounds"))
        }

        if (authorizedSettings.contains(.carPlay)) {
            settingsArray.append("ua_notification_type_car_play".localized(comment: "CarPlay"))
        }

        if (authorizedSettings.contains(.lockScreen)) {
            settingsArray.append("ua_notification_type_lock_screen".localized(comment: "Lock Screen"))
        }

        if (authorizedSettings.contains(.notificationCenter)) {
            settingsArray.append("ua_notification_type_notification_center".localized(comment: "Notification Center"))
        }

        if (authorizedSettings.contains(.criticalAlert)) {
            settingsArray.append("ua_notification_type_critical_alert".localized(comment: "Critical Alert"))
        }

        if (authorizedSettings.contains(.announcement)) {
            settingsArray.append("ua_notification_type_announcement".localized(comment: "AirPod Announcement"))
        }
        
        if (settingsArray.count == 0) {
            settingsArray.append("ua_push_settings_link_disabled_title".localized(comment: "Pushes Currently Disabled"))
        }

        return settingsArray.joined(separator: ", ")
    }
}

internal extension String {
    func localized(tableName: String = "UAPushUI", comment: String = "") -> String {
        return NSLocalizedString(self, tableName: tableName, comment: comment)
    }
    
    func localizedWithFormat(count:Int) -> String {
        return String.localizedStringWithFormat(localized(), count)
    }
}
