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
        return UAirship.shared().privacyManager.isEnabled(UAFeatures.inAppAutomation)
    }
    set (value) {
        if (value) {
            UAirship.shared().privacyManager.enable(UAFeatures.inAppAutomation)
        } else {
            UAirship.shared().privacyManager.disableFeatures(UAFeatures.inAppAutomation)
        }
    }
}

var inAppAutomationDisplayInterval: Int {
    get {
        return Int(UAInAppAutomation.shared()!.inAppMessageManager.displayInterval)
    }
    set (value) {
        UAInAppAutomation.shared().inAppMessageManager.displayInterval = TimeInterval(value)
    }
}

class DeviceInfoViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @objc public static var tagsViewName = "tags"
    let tagsSegue = "tagsSegue"

    var launchPathComponents : [String]?
    var launchCompletionHandler : (() -> Void)?

    private let localizedNone = "ua_none".localized(comment: "None")
    private let sectionCount = 8
    
    @IBOutlet private var tableView: UITableView!

    /* Section
     * Note: Number of sections and sections for row are defined in their respective
     * table view data source methods
     */
    let privacyManagerSettings = 0,
    pushSettings = 1,
    inAppAutomationSettings = 2,
    deviceSettings = 3,
    locationSettings = 4,
    sdkInfo = 5,
    appInfo = 6

    // Privacy Manager settings
    private let inAppAutomationFeatureEnabled = IndexPath(row: 0, section: 0),
                messageCenterFeatureEnabled = IndexPath(row: 1, section: 0),
                pushFeatureEnabled = IndexPath(row: 2, section: 0),
                chatFeatureEnabled = IndexPath(row: 3, section: 0),
                analyticsFeatureEnabled = IndexPath(row: 4, section: 0),
                tagsAndAttributesFeatureEnabled = IndexPath(row: 5, section: 0),
                contactsFeatureEnabled = IndexPath(row: 6, section: 0),
                locationFeatureEnabled = IndexPath(row: 7, section: 0)

    // Push settings
    private let notificationsEnabled = IndexPath(row: 0, section: 1)

    // In-App automation settings
    private let displayInterval = IndexPath(row: 0, section: 2)
    
    // Device settings
    private let channelID = IndexPath(row: 0, section: 3),
    username = IndexPath(row: 1, section: 3),
    namedUser = IndexPath(row: 2, section: 3),
    tags = IndexPath(row: 3, section: 3),
    tagGroups = IndexPath(row: 4, section: 3),
    associatedIdentifiers = IndexPath(row: 5, section: 3),
    channelAttributes = IndexPath(row: 6, section: 3),
    namedUserAttributes = IndexPath(row: 7, section: 3),
    timezone = IndexPath(row: 8, section: 3)

    // Location settings
    private let locationEnabled = IndexPath(row: 0, section: 4)

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
        case privacyManagerSettings:
            return "ua_device_info_privacy_manager_settings".localized()
        case sdkInfo:
            return "ua_device_info_SDK_info".localized()
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
            return 1
        case inAppAutomationSettings:
            return 1
        case deviceSettings:
            return 9
        case privacyManagerSettings:
            return 8
        case locationSettings:
            return 1
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
        case notificationsEnabled:
            cell.title.text = "ua_device_info_enable_notifications".localized()
            cell.cellSwitch.isHidden = false
            cell.cellSwitch.isOn = UAirship.push()?.userPushNotificationsEnabled ?? false
            cell.subtitle?.text = pushTypeString()
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
            cell.displayIntervalStepper.tintColor = ThemeManager.shared.currentTheme.WidgetTint;
        case inAppAutomationFeatureEnabled:
            cell.title.text = "ua_device_info_in_app_automation_feature_enabled".localized()
            cell.cellSwitch.isHidden = false
            cell.cellSwitch.isOn = UAirship.shared().privacyManager.isEnabled(UAFeatures.inAppAutomation)
            cell.subtitle?.adjustsFontSizeToFitWidth = true
            cell.subtitle?.minimumScaleFactor = 0.25
            cell.subtitle?.numberOfLines = 2
        case messageCenterFeatureEnabled:
            cell.title.text = "ua_device_info_message_center_feature_enabled".localized()
            cell.cellSwitch.isHidden = false
            cell.cellSwitch.isOn = UAirship.shared().privacyManager.isEnabled(UAFeatures.messageCenter)
            cell.subtitle?.adjustsFontSizeToFitWidth = true
            cell.subtitle?.minimumScaleFactor = 0.25
            cell.subtitle?.numberOfLines = 2
        case pushFeatureEnabled:
            cell.title.text = "ua_device_info_push_feature_enabled".localized()
            cell.cellSwitch.isHidden = false
            cell.cellSwitch.isOn = UAirship.shared().privacyManager.isEnabled(UAFeatures.push)
            cell.subtitle?.adjustsFontSizeToFitWidth = true
            cell.subtitle?.minimumScaleFactor = 0.25
            cell.subtitle?.numberOfLines = 2
        case chatFeatureEnabled:
            cell.title.text = "ua_device_info_chat_feature_enabled".localized()
            cell.cellSwitch.isHidden = false
            cell.cellSwitch.isOn = UAirship.shared().privacyManager.isEnabled(UAFeatures.chat)
            cell.subtitle?.adjustsFontSizeToFitWidth = true
            cell.subtitle?.minimumScaleFactor = 0.25
            cell.subtitle?.numberOfLines = 2
        case analyticsFeatureEnabled:
            cell.title.text = "ua_device_info_analytics_feature_enabled".localized()
            cell.cellSwitch.isHidden = false
            cell.cellSwitch.isOn = UAirship.shared().privacyManager.isEnabled(UAFeatures.analytics)
            cell.subtitle?.adjustsFontSizeToFitWidth = true
            cell.subtitle?.minimumScaleFactor = 0.25
            cell.subtitle?.numberOfLines = 2
        case tagsAndAttributesFeatureEnabled:
            cell.title.text = "ua_device_info_tags_and_attributes_feature_enabled".localized()
            cell.cellSwitch.isHidden = false
            cell.cellSwitch.isOn = UAirship.shared().privacyManager.isEnabled(UAFeatures.tagsAndAttributes)
            cell.subtitle?.adjustsFontSizeToFitWidth = true
            cell.subtitle?.minimumScaleFactor = 0.25
            cell.subtitle?.numberOfLines = 2
        case contactsFeatureEnabled:
            cell.title.text = "ua_device_info_contacts_feature_enabled".localized()
            cell.cellSwitch.isHidden = false
            cell.cellSwitch.isOn = UAirship.shared().privacyManager.isEnabled(UAFeatures.contacts)
            cell.subtitle?.adjustsFontSizeToFitWidth = true
            cell.subtitle?.minimumScaleFactor = 0.25
            cell.subtitle?.numberOfLines = 2
        case locationFeatureEnabled:
            cell.title.text = "ua_device_info_location_feature_enabled".localized()
            cell.cellSwitch.isHidden = false
            cell.cellSwitch.isOn = UAirship.shared().privacyManager.isEnabled(UAFeatures.location)
            cell.subtitle?.adjustsFontSizeToFitWidth = true
            cell.subtitle?.minimumScaleFactor = 0.25
            cell.subtitle?.numberOfLines = 2
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
        case tagGroups:
            cell.title.text = "ua_device_info_tag_groups".localized()
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
        case namedUserAttributes:
            cell.title.text = "ua_device_info_named_user_attributes".localized()
            cell.accessoryType = .disclosureIndicator
        case locationEnabled:
            cell.title.text = "ua_device_info_enable_location_enabled".localized()

            cell.cellSwitch.isHidden = false
            cell.cellSwitch.isOn = UAirship.shared().privacyManager.isEnabled(UAFeatures.location)

            let optedInToLocation = UALocation.shared().isLocationOptedIn()

            if (UAirship.shared().privacyManager.isEnabled(UAFeatures.location) && !optedInToLocation) {
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
        case notificationsEnabled:
            cell.cellSwitch.setOn(!cell.cellSwitch.isOn, animated: true)
            UAirship.push().userPushNotificationsEnabled = cell.cellSwitch.isOn
        case channelID:
            if (UAirship.channel().identifier != nil) {
                UIPasteboard.general.string = cell.subtitle?.text
                showCopiedAlert()
            }
        case username:
            UAMessageCenter.shared().user.getData({ (userData) in
                UIPasteboard.general.string = userData.username
                self.showCopiedAlert()
            })
        case namedUser:
            performSegue(withIdentifier: "namedUserSegue", sender: self)
        case tags:
            performSegue(withIdentifier: "tagsSegue", sender: self)
        case tagGroups:
            performSegue(withIdentifier: "tagGroupsSegue", sender: self)
        case associatedIdentifiers:
            performSegue(withIdentifier: "associatedIdentifiersSegue", sender: self)
        case channelAttributes:
            performSegue(withIdentifier: "channelAttributesSegue", sender: self)
        case namedUserAttributes:
            performSegue(withIdentifier: "namedUserAttributesSegue", sender: self)
        case sdkVersion:
            UIPasteboard.general.string = cell.subtitle?.text
            showCopiedAlert()
        case inAppAutomationFeatureEnabled:
            cell.cellSwitch.setOn(!cell.cellSwitch.isOn, animated: true)
            if (cell.cellSwitch.isOn) {
                UAirship.shared().privacyManager.enable(UAFeatures.inAppAutomation)
            } else {
                UAirship.shared().privacyManager.disableFeatures(UAFeatures.inAppAutomation)
            }
        case messageCenterFeatureEnabled:
            cell.cellSwitch.setOn(!cell.cellSwitch.isOn, animated: true)
            if (cell.cellSwitch.isOn) {
                UAirship.shared().privacyManager.enable(UAFeatures.messageCenter)
            } else {
                UAirship.shared().privacyManager.disableFeatures(UAFeatures.messageCenter)
            }
        case pushFeatureEnabled:
            cell.cellSwitch.setOn(!cell.cellSwitch.isOn, animated: true)
            if (cell.cellSwitch.isOn) {
                UAirship.shared().privacyManager.enable(UAFeatures.push)
            } else {
                UAirship.shared().privacyManager.disableFeatures(UAFeatures.push)
            }
        case chatFeatureEnabled:
            cell.cellSwitch.setOn(!cell.cellSwitch.isOn, animated: true)
            if (cell.cellSwitch.isOn) {
                UAirship.shared().privacyManager.enable(UAFeatures.chat)
            } else {
                UAirship.shared().privacyManager.disableFeatures(UAFeatures.chat)
            }
        case analyticsFeatureEnabled:
            cell.cellSwitch.setOn(!cell.cellSwitch.isOn, animated: true)
            if (cell.cellSwitch.isOn) {
                UAirship.shared().privacyManager.enable(UAFeatures.analytics)
            } else {
                UAirship.shared().privacyManager.disableFeatures(UAFeatures.analytics)
            }
        case tagsAndAttributesFeatureEnabled:
            cell.cellSwitch.setOn(!cell.cellSwitch.isOn, animated: true)
            if (cell.cellSwitch.isOn) {
                UAirship.shared().privacyManager.enable(UAFeatures.tagsAndAttributes)
            } else {
                UAirship.shared().privacyManager.disableFeatures(UAFeatures.tagsAndAttributes)
            }
        case contactsFeatureEnabled:
            cell.cellSwitch.setOn(!cell.cellSwitch.isOn, animated: true)
            if (cell.cellSwitch.isOn) {
                UAirship.shared().privacyManager.enable(UAFeatures.contacts)
            } else {
                UAirship.shared().privacyManager.disableFeatures(UAFeatures.contacts)
            }
        case locationFeatureEnabled:
            cell.cellSwitch.setOn(!cell.cellSwitch.isOn, animated: true)
            if (cell.cellSwitch.isOn) {
                UAirship.shared().privacyManager.enable(UAFeatures.location)
            } else {
                UAirship.shared().privacyManager.disableFeatures(UAFeatures.location)
            }
        case locationEnabled:
            cell.cellSwitch.setOn(!cell.cellSwitch.isOn, animated: true)
            if (cell.cellSwitch.isOn) {
                UAirship.shared().privacyManager.enable(UAFeatures.location)
            } else {
                UAirship.shared().privacyManager.disableFeatures(UAFeatures.location)
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
