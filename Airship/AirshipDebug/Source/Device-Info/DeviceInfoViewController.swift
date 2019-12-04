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


class DeviceInfoCell: UITableViewCell {
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var subtitle: UILabel!
    @IBOutlet weak var cellSwitch: UISwitch!
    @IBOutlet weak var displayIntervalStepper: UIStepper!

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
    
    @IBAction func stepperValueChanged(_ sender: UIStepper) {
        let stepperValue = Int(sender.value)
        subtitle.text = "ua_timeinterval_description_integer_seconds".localizedWithFormat(count:stepperValue)
        inAppAutomationDisplayInterval = stepperValue
    }
    
}

var isInAppAutomationEnabled: Bool {
    get {
        return UAInAppMessageManager.shared().isEnabled
    }
    set (value) {
        UAInAppMessageManager.shared().isEnabled = value
    }
}

var inAppAutomationDisplayInterval: Int {
    get {
        return Int(UAInAppMessageManager.shared()!.displayInterval)
    }
    set (value) {
        UAInAppMessageManager.shared().displayInterval = TimeInterval(value)
    }
}

class DeviceInfoViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @objc public static var tagsViewName = "tags"
    let tagsSegue = "tagsSegue"

    var launchPathComponents : [String]?
    var launchCompletionHandler : (() -> Void)?

    private let localizedNone = "ua_none".localized(comment: "None")
    private let sectionCount = 7
    
    @IBOutlet private var tableView: UITableView!

    /* Section
     * Note: Number of sections and sections for row are defined in their respective
     * table view data source methods
     */
    let pushSettings = 0,
    inAppAutomationSettings = 1,
    deviceSettings = 2,
    locationSettings = 3,
    analyticsSettings = 4,
    sdkInfo = 5,
    appInfo = 6

    // Push settings
    private let pushEnabled = IndexPath(row: 0, section: 0),
    lastPayload = IndexPath(row: 1, section: 0)

    // In-App automation settings
    private let inAppAutomationEnabled = IndexPath(row: 0, section: 1),
    displayInterval = IndexPath(row: 1, section: 1)
    
    // Device settings
    private let channelID = IndexPath(row: 0, section: 2),
    username = IndexPath(row: 1, section: 2),
    namedUser = IndexPath(row: 2, section: 2),
    tags = IndexPath(row: 3, section: 2),
    associatedIdentifiers = IndexPath(row: 4, section: 2),
    channelAttributes = IndexPath(row: 5, section: 2)

    // Location settings
    private let locationEnabled = IndexPath(row: 0, section: 3),
    timezone = IndexPath(row: 1, section: 3)

    // Analytics settigns
    private let analyticsEnabled = IndexPath(row: 0, section: 4)
    
    // SDK Info
    private let sdkVersion = IndexPath(row: 0, section: 5),
    localeInfo = IndexPath(row: 1, section: 5)

    // App Info
    private let appVersion = IndexPath(row: 0, section: 6)
    
    @objc func pushSettingsButtonTapped(sender:Any) {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:],completionHandler: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let image = UIImage(named: "Settings", in:Bundle(identifier: "com.urbanairship.AirshipDebug"), compatibleWith: nil)

        let pushSettings: UIBarButtonItem = UIBarButtonItem(image:image, style:.done, target: self, action: #selector(pushSettingsButtonTapped))
        self.navigationItem.rightBarButtonItem = pushSettings

        tableView.dataSource = self
        tableView.delegate = self
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(DeviceInfoViewController.refreshView),
            name: NSNotification.Name(rawValue: UAChannelUpdatedEvent),
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
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor:ThemeManager.shared.currentTheme.NavigationBarText]
        navigationController?.navigationBar.barTintColor = ThemeManager.shared.currentTheme.NavigationBarBackground;
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated);

        if let launchPathComponents = launchPathComponents {
            if (launchPathComponents.count > 0) {
                switch (launchPathComponents[0]) {
                case DeviceInfoViewController.tagsViewName:
                    performSegue(withIdentifier: tagsSegue, sender: self)
                default:
                    break
                }
            }
        }
        launchPathComponents = nil
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
            return "ua_device_info_push_settings".localized()
        case inAppAutomationSettings:
            return "ua_device_info_in_app_automation_settings".localized()
        case deviceSettings:
            return "ua_device_info_device_settings".localized()
        case sdkInfo:
            return "ua_device_info_SDK_info".localized()
        case analyticsSettings:
            return "ua_device_info_analytics_settings".localized()
        case locationSettings:
            return "ua_device_info_location_settings".localized()
        case appInfo:
            return "ua_device_info_app_info".localized()
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
            return 2
        case inAppAutomationSettings:
            return 2
        case deviceSettings:
            return 6
        case analyticsSettings:
            return 1
        case locationSettings:
            return 2
        case sdkInfo:
            return 2
        case appInfo:
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
        cell.displayIntervalStepper.backgroundColor = ThemeManager.shared.currentTheme.Background;

        // Cell switch, stepper and disclosure indicator are hidden by default
        cell.cellSwitch.isHidden = true
        cell.displayIntervalStepper.isHidden = true;

        // Cells will do the switching
        cell.cellSwitch.isUserInteractionEnabled = false
        cell.accessoryType = .none
        cell.subtitle.text = nil

        switch indexPath {
        case pushEnabled:
            cell.title.text = "ua_device_info_push_settings".localized()
            cell.subtitle.text = "ua_device_info_enable_push".localized()
            cell.cellSwitch.isHidden = false
            cell.cellSwitch.isOn = UAirship.push()?.userPushNotificationsEnabled ?? false
            cell.subtitle?.text = pushTypeString()
            cell.subtitle?.adjustsFontSizeToFitWidth = true;
            cell.subtitle?.minimumScaleFactor = 0.25;
            cell.subtitle?.numberOfLines = 1;
        case inAppAutomationEnabled:
            cell.title.text = "ua_device_info_in_app_automation_settings".localized()
            cell.subtitle?.text = " "
            cell.cellSwitch.isHidden = false
            cell.cellSwitch.isOn = isInAppAutomationEnabled
            cell.subtitle?.adjustsFontSizeToFitWidth = true;
            cell.subtitle?.minimumScaleFactor = 0.25;
            cell.subtitle?.numberOfLines = 1;
        case displayInterval:
            cell.title.text = "ua_device_info_in_app_automation_display_interval".localized()
            cell.subtitle?.text = "ua_timeinterval_description_integer_seconds".localizedWithFormat(count:inAppAutomationDisplayInterval)
            cell.subtitle?.adjustsFontSizeToFitWidth = true;
            cell.subtitle?.minimumScaleFactor = 0.25;
            cell.subtitle?.numberOfLines = 1;
            cell.displayIntervalStepper.isHidden = false;
            cell.displayIntervalStepper.value = Double(inAppAutomationDisplayInterval)
        case channelID:
            cell.title.text = "ua_device_info_channel_id".localized()
            cell.subtitle.text = UAirship.channel().identifier
        case username:
            UAMessageCenter.shared().user.getData({ (userData) in
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
            if (UAirship.channel().tags.count > 0) {
                cell.subtitle?.text = UAirship.channel().tags.joined(separator: ", ")
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
        case channelAttributes:
            cell.title.text = "ua_device_info_channel_attributes".localized()
            cell.accessoryType = .disclosureIndicator
        case lastPayload:
            cell.title.text = "ua_device_info_last_push_payload".localized()
            cell.subtitle.text = ""
            cell.accessoryType = .disclosureIndicator
        case analyticsEnabled:
            cell.title.text = "ua_device_info_analytics_enabled".localized()
            cell.subtitle?.text = "ua_device_info_enable_analytics_tracking".localized()

            cell.cellSwitch.isHidden = false
            cell.cellSwitch.isOn = UAirship.analytics().isEnabled
        case locationEnabled:
            cell.title.text = "ua_device_info_enable_location_enabled".localized()

            cell.cellSwitch.isHidden = false
            cell.cellSwitch.isOn = UALocation.shared().isLocationUpdatesEnabled

            let optedInToLocation = UALocation.shared().isLocationOptedIn()

            if (UALocation.shared().isLocationUpdatesEnabled && !optedInToLocation) {
                cell.subtitle?.text = "ua_location_enabled_detail".localized(comment: "Enable GPS and WIFI Based Location detail label") + " - NOT OPTED IN"
            } else {
                cell.subtitle?.text = localizedNone
            }
        case sdkVersion:
            cell.title.text = "ua_device_info_sdk_version".localized()
            cell.subtitle?.text = UAirshipVersion.get()
        case localeInfo:
            cell.title.text = "ua_device_info_locale".localized()
            cell.subtitle?.text = NSLocale.autoupdatingCurrent.identifier
        case appVersion:
            cell.title.text = "ua_device_info_app_version".localized()
            cell.subtitle?.text = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String
        case timezone:
            cell.title.text = "ua_device_info_timezone".localized()
            cell.subtitle?.text = TimeZone.current.identifier
            
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
            if (UAirship.channel().identifier != nil) {
                UIPasteboard.general.string = cell.subtitle?.text
                showCopiedAlert()
            }
        case inAppAutomationEnabled:
            cell.cellSwitch.setOn(!cell.cellSwitch.isOn, animated: true)
            let isEnabled = cell.cellSwitch.isOn
            isInAppAutomationEnabled = isEnabled
        case username:
            UAMessageCenter.shared().user.getData({ (userData) in
                UIPasteboard.general.string = userData.username
                self.showCopiedAlert()
            })
        case namedUser:
            performSegue(withIdentifier: "namedUserSegue", sender: self)
        case tags:
            performSegue(withIdentifier: "tagsSegue", sender: self)
        case associatedIdentifiers:
            performSegue(withIdentifier: "associatedIdentifiersSegue", sender: self)
        case channelAttributes:
            performSegue(withIdentifier: "channelAttributesSegue", sender: self)
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
            UALocation.shared().isLocationUpdatesEnabled = cell.cellSwitch.isOn
        default:
            break
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func showCopiedAlert() {
        DispatchQueue.main.async {
            let message = "ua_copied_to_clipboard".localized(comment: "Copied to clipboard string")

            let alert = UIAlertController(title: nil, message: message, preferredStyle: UIAlertController.Style.alert)
            let buttonTitle = "ua_ok".localized()

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
