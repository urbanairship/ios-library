/* Copyright Urban Airship and Contributors */

import UIKit
import AirshipKit

class DeviceInfoCell: UITableViewCell {
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

class DeviceInfoViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    private let localizedNone = NSLocalizedString("None", tableName: "UAPushUI", comment: "None")

    private let sectionCount = 5

    @IBOutlet private var tableView: UITableView!

    /* Section
     * Note: Number of sections and sections for row are defined in their respective
     * table view data source methods
     */
    let pushSettings = 0,
    deviceSettings = 1,
    sdkSettings = 2,
    analyticsSettings = 3,
    locationSettings = 4

    // Indexes
    private let pushEnabled = IndexPath(row: 0, section: 0),
    channelID = IndexPath(row: 0, section: 1),
    username = IndexPath(row: 1, section: 1),
    namedUser = IndexPath(row: 2, section: 1),
    tags = IndexPath(row: 3, section: 1),
    associatedIdentifiers = IndexPath(row: 4, section: 1),
    lastPayload = IndexPath(row: 5, section: 1),
    sdkVersion = IndexPath(row: 0, section: 2),
    locationEnabled = IndexPath(row: 0, section: 3),
    analyticsEnabled = IndexPath(row: 0, section: 4)

    @objc func pushSettingsButtonTapped(sender:Any) {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:],completionHandler: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let image = UIImage(named: "Settings", in:Bundle(identifier: "com.urbanairship.AirshipDebugKit"), compatibleWith: nil)

        let pushSettings: UIBarButtonItem = UIBarButtonItem(image:image, style:.done, target: self, action: #selector(pushSettingsButtonTapped))
        self.navigationItem.rightBarButtonItem = pushSettings

        tableView.dataSource = self
        tableView.delegate = self
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(DeviceInfoViewController.refreshView),
            name: NSNotification.Name(rawValue: "channelIDUpdated"),
            object: nil);
        
        // add observer to didBecomeActive to update upon retrun from system settings screen
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(DeviceInfoViewController.didBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil)
    }

    func setTableViewTheme() {
        tableView.backgroundColor = ThemeManager.shared.currentTheme.Background;
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor:ThemeManager.shared.currentTheme.PrimaryText]
        navigationController?.navigationBar.barTintColor = ThemeManager.shared.currentTheme.NavigationBarBackground;
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated);
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
            return "ua_device_info_push_settings".localized()
        case deviceSettings:
            return "ua_device_info_device_settings".localized()
        case sdkSettings:
            return "ua_device_info_SDK_settings".localized()
        case analyticsSettings:
            return "ua_device_info_location_settings".localized()
        case locationSettings:
            return "ua_device_info_analytics_settings".localized()
        default:
            return ""
        }
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerView = view as? UITableViewHeaderFooterView {
            headerView.textLabel?.textColor = ThemeManager.shared.currentTheme.WidgetTint
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case pushSettings:
            return 1
        case deviceSettings:
            return 6
        case sdkSettings:
            return 1
        case analyticsSettings:
            return 1
        case locationSettings:
            return 1
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell:DeviceInfoCell = tableView.dequeueReusableCell(withIdentifier: "DeviceInfoCell", for: indexPath) as! DeviceInfoCell

        cell.backgroundColor = ThemeManager.shared.currentTheme.Background
        cell.title.textColor = ThemeManager.shared.currentTheme.PrimaryText
        cell.subtitle?.textColor = ThemeManager.shared.currentTheme.SecondaryText
        cell.cellSwitch.onTintColor = ThemeManager.shared.currentTheme.WidgetTint
        cell.cellSwitch.tintColor = ThemeManager.shared.currentTheme.WidgetTint

        // Cell switch and disclosure indicator are hidden by default
        cell.cellSwitch.isHidden = true
        cell.accessoryType = .none

        switch indexPath {
        case pushEnabled:
            cell.title.text = "ua_device_info_push_settings".localized()
            cell.subtitle.text = "ua_device_info_enable_push".localized()
            cell.cellSwitch.isHidden = false
            cell.cellSwitch.isOn = UAirship.push()?.userPushNotificationsEnabled ?? false
            cell.subtitle?.text = pushTypeString()
        case channelID:
            cell.title.text = "ua_device_info_channel_id".localized()
            cell.subtitle.text = UAirship.push().channelID
        case username:
            UAirship.inboxUser()?.getData({ (userData) in
                DispatchQueue.main.async {
                    cell.title.text = "ua_device_info_username".localized()
                    cell.subtitle.text = userData.username
                }
            })
        case namedUser:
            cell.title.text = "ua_device_info_named_user".localized()
            cell.subtitle?.text = UAirship.namedUser().identifier == nil ? localizedNone : UAirship.namedUser().identifier
            cell.accessoryType = .disclosureIndicator
        case tags:
            cell.title.text = "ua_device_info_tags".localized()
            if (UAirship.push().tags.count > 0) {
                cell.subtitle?.text = UAirship.push().tags.joined(separator: ", ")
            } else {
                cell.subtitle?.text = localizedNone
            }

            cell.accessoryType = .disclosureIndicator
        case associatedIdentifiers:
            cell.title.text = "ua_device_info_associated_identifiers".localized()

            if let identifiers = UserDefaults.standard.object(forKey: customIdentifiersKey) as? Dictionary<String, Any> {
                cell.subtitle.text = "\(identifiers)"
            } else {
                cell.subtitle.text = localizedNone
            }
            cell.accessoryType = .disclosureIndicator
        case lastPayload:
            cell.title.text = "ua_device_info_last_payload".localized()
            cell.subtitle.text = ""
            cell.accessoryType = .disclosureIndicator
        case sdkVersion:
            cell.title.text = "ua_device_info_sdk_version".localized()
            cell.subtitle?.text = UAirshipVersion.get()
        case analyticsEnabled:
            cell.title.text = "ua_device_info_analytics_enabled".localized()
            cell.subtitle?.text = "ua_device_info_enable_analytics_tracking".localized()

            cell.cellSwitch.isHidden = false
            cell.cellSwitch.isOn = UAirship.analytics()?.isEnabled ?? false
        case locationEnabled:
            cell.title.text = "ua_device_info_enable_location_enabled".localized()

            cell.cellSwitch.isHidden = false
            cell.cellSwitch.isOn = UAirship.shared()?.locationPoviderDelegate?.isLocationUpdatesEnabled ?? false

            let optedInToLocation = UAirship.shared()?.locationPoviderDelegate?.isLocationOptedIn() ?? false

            if (UAirship.shared().locationPoviderDelegate?.isLocationUpdatesEnabled ?? false && !optedInToLocation) {
                cell.subtitle?.text = NSLocalizedString("UA_Location_Enabled_Detail", tableName: "UAPushUI", comment: "Enable GPS and WIFI Based Location detail label") + " - NOT OPTED IN"
            } else {
                cell.subtitle?.text = localizedNone
            }

        default:
            break
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath) as! DeviceInfoCell

        switch indexPath {
        case pushEnabled:
            cell.cellSwitch.setOn(!cell.cellSwitch.isOn, animated: true)
            UAirship.push().userPushNotificationsEnabled = cell.cellSwitch.isOn
        case channelID:
            if (UAirship.push().channelID != nil) {
                UIPasteboard.general.string = cell.subtitle?.text
                showCopiedAlert()
            }
        case username:
            UAirship.inboxUser()?.getData({ (userData) in
                UIPasteboard.general.string = userData.username
                self.showCopiedAlert()
            })
        case namedUser:
            performSegue(withIdentifier: "namedUserSegue", sender: self)
        case tags:
            performSegue(withIdentifier: "tagsSegue", sender: self)
        case associatedIdentifiers:
            performSegue(withIdentifier: "associatedIdentifiersSegue", sender: self)
        case lastPayload:
            performSegue(withIdentifier: "lastPayloadSegue", sender: self)
        case sdkVersion:
            UIPasteboard.general.string = cell.subtitle?.text
            showCopiedAlert()
        case analyticsEnabled:
            cell.cellSwitch.setOn(!cell.cellSwitch.isOn, animated: true)
            UAirship.shared().analytics.isEnabled = cell.cellSwitch.isOn
        case locationEnabled:
            cell.cellSwitch.setOn(!cell.cellSwitch.isOn, animated: true)
            UAirship.shared().locationPoviderDelegate?.isLocationUpdatesEnabled = cell.cellSwitch.isOn
        default:
            break
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func showCopiedAlert() {
        DispatchQueue.main.async {
            let message = NSLocalizedString("UA_Copied_To_Clipboard", tableName: "UAPushUI", comment: "Copied to clipboard string")

            let alert = UIAlertController(title: nil, message: message, preferredStyle: UIAlertController.Style.alert)
            let buttonTitle = NSLocalizedString("UA_OK", tableName: "UAPushUI", comment: "OK button string")

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
            settingsArray.append(NSLocalizedString("UA_Notification_Type_Alerts", tableName: "UAPushUI", comment: "Alerts"))
        }

        if (authorizedSettings.contains(.badge)){
            settingsArray.append(NSLocalizedString("UA_Notification_Type_Badges", tableName: "UAPushUI", comment: "Badges"))
        }

        if (authorizedSettings.contains(.sound)) {
            settingsArray.append(NSLocalizedString("UA_Notification_Type_Sounds", tableName: "UAPushUI", comment: "Sounds"))
        }

        if (authorizedSettings.contains(.carPlay)) {
            settingsArray.append(NSLocalizedString("UA_Notification_Type_CarPlay", tableName: "UAPushUI", comment: "CarPlay"))
        }

        if (authorizedSettings.contains(.lockScreen)) {
            settingsArray.append(NSLocalizedString("UA_Notification_Type_LockScreen", tableName: "UAPushUI", comment: "Lock Screen"))
        }

        if (authorizedSettings.contains(.notificationCenter)) {
            settingsArray.append(NSLocalizedString("UA_Notification_Type_NotificationCenter", tableName: "UAPushUI", comment: "Notification Center"))
        }

        if (authorizedSettings.contains(.criticalAlert)) {
            settingsArray.append(NSLocalizedString("UA_Notification_Type_CriticalAlert", tableName: "UAPushUI", comment: "Critical Alert"))
        }

        if (settingsArray.count == 0) {
            return NSLocalizedString("UA_Push_Settings_Link_Disabled_Title", tableName: "UAPushUI", comment: "Pushes Currently Disabled")
        }

        return settingsArray.joined(separator: ", ")
    }

}
