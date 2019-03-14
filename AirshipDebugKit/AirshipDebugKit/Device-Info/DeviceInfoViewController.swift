/* Copyright Urban Airship and Contributors */

import UIKit
import AirshipKit

class DeviceInfoViewController: UITableViewController {
    @IBOutlet weak var pushSettingCell: UITableViewCell!
    @IBOutlet weak var pushSettingsTitle: UILabel!
    @IBOutlet weak var pushSettingsSubtitleLabel: UILabel!

    @IBOutlet weak var channelIDCell: UITableViewCell!
    @IBOutlet weak var channelIDTitle: UILabel!
    @IBOutlet weak var channelIDSubtitleLabel: UILabel!

    @IBOutlet weak var namedUserCell: UITableViewCell!
    @IBOutlet weak var namedUserTitle: UILabel!
    @IBOutlet weak var namedUserSubtitleLabel: UILabel!

    @IBOutlet weak var tagsCell: UITableViewCell!
    @IBOutlet weak var tagsTitle: UILabel!
    @IBOutlet weak var tagsSubtitleLabel: UILabel!

    @IBOutlet weak var associatedIdentifiersTitle: UILabel!
    @IBOutlet weak var associatedIdentifiersCell:UITableViewCell!

    @IBOutlet weak var lastPayloadTitle: UILabel!
    @IBOutlet weak var lastPayloadCell: UITableViewCell!

    @IBOutlet weak var sdkVersionCell: UITableViewCell!
    @IBOutlet weak var sdkVersionTitle: UILabel!
    @IBOutlet weak var sdkVersionSubtitleLabel: UILabel!

    @IBOutlet weak var locationEnabledCell: UITableViewCell!
    @IBOutlet weak var locationEnabledTitle: UILabel!
    @IBOutlet weak var locationEnabledSubtitleLabel: UILabel!

    @IBOutlet weak var pushEnabledSwitch: UISwitch!
    @IBOutlet weak var locationEnabledSwitch: UISwitch!

    @IBOutlet weak var analyticsCell: UITableViewCell!
    @IBOutlet weak var analyticsTitle: UILabel!
    @IBOutlet weak var analyticsSubtitleLabel: UILabel!
    @IBOutlet weak var analyticsSwitch: UISwitch!

    @IBAction func switchValueChanged(_ sender: UISwitch) {
        switch sender {
        case pushEnabledSwitch:
            UAirship.push().userPushNotificationsEnabled = pushEnabledSwitch.isOn
            break
        default:
            break
        }
        
        UAirship.location().isLocationUpdatesEnabled = locationEnabledSwitch.isOn
        UAirship.shared().analytics.isEnabled = analyticsSwitch.isOn
        
        updateSwitches()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
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
        
        locationEnabledTitle.text = NSLocalizedString("UA_Location_Enabled", tableName: "UAPushUI", comment: "Location Enabled label")
        locationEnabledSubtitleLabel.text = NSLocalizedString("UA_Location_Enabled_Detail", tableName: "UAPushUI", comment: "Enable GPS and WIFI Based Location detail label")
        pushEnabledSwitch.isOn = UAirship.push().userPushNotificationsEnabled
    }

    func setCellTheme() {
        pushSettingCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        pushSettingsTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        pushSettingsSubtitleLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText

        channelIDCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        channelIDTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        channelIDSubtitleLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText

        namedUserCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        namedUserTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        namedUserSubtitleLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText

        tagsCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        tagsTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        tagsSubtitleLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText

        associatedIdentifiersCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        associatedIdentifiersTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText

        lastPayloadCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        lastPayloadTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText

        sdkVersionCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        sdkVersionTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        sdkVersionSubtitleLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText

        locationEnabledCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        locationEnabledTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        locationEnabledSubtitleLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText

        analyticsCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        analyticsTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        analyticsSubtitleLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText
        analyticsSwitch.onTintColor = ThemeManager.shared.currentTheme.WidgetTint
        analyticsSwitch.tintColor = ThemeManager.shared.currentTheme.WidgetTint
    }

    func setTableViewTheme() {
        tableView.backgroundColor = ThemeManager.shared.currentTheme.Background;
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor:ThemeManager.shared.currentTheme.PrimaryText]
        navigationController?.navigationBar.barTintColor = ThemeManager.shared.currentTheme.NavigationBarBackground;
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated);
        updateSwitches()
    }
    
    fileprivate func updateSwitches() {
        // Update switches
        pushEnabledSwitch.isOn = UAirship.push().userPushNotificationsEnabled
        let optedInToLocation = (UAirship.location()?.isLocationOptedIn())!
        locationEnabledSwitch.isOn = UAirship.location().isLocationUpdatesEnabled
        if (UAirship.location().isLocationUpdatesEnabled && !optedInToLocation) {
            locationEnabledSubtitleLabel.text = NSLocalizedString("UA_Location_Enabled_Detail", tableName: "UAPushUI", comment: "Enable GPS and WIFI Based Location detail label") + " - NOT OPTED IN"
        }
        
        analyticsSwitch.isOn = UAirship.shared().analytics.isEnabled
    }
    
    // this is necessary to update the view when returning from the system settings screen
    @objc func didBecomeActive () {
        refreshView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setCellTheme()
        setTableViewTheme()
        refreshView()
    }
    
    @objc func refreshView() {
        channelIDSubtitleLabel?.text = UAirship.push().channelID
        
        namedUserSubtitleLabel?.text = UAirship.namedUser().identifier == nil ? NSLocalizedString("None", tableName: "UAPushUI", comment: "None") : UAirship.namedUser().identifier
        
        if (UAirship.push().tags.count > 0) {
            self.tagsSubtitleLabel?.text = UAirship.push().tags.joined(separator: ", ")
        } else {
            self.tagsSubtitleLabel?.text = NSLocalizedString("None", tableName: "UAPushUI", comment: "None")
        }
        
        pushSettingsSubtitleLabel.text = pushTypeString()
        
        sdkVersionSubtitleLabel.text = UAirshipVersion.get()
        
        updateSwitches()
        
        tableView.reloadData()
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

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch tableView.cellForRow(at: indexPath) {
        case pushSettingCell:
            // redirect click on push enabled cell to system settings
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,options: [:],completionHandler: nil)
            break
        case channelIDCell:
            if (UAirship.push().channelID != nil) {
                UIPasteboard.general.string = channelIDSubtitleLabel?.text
                
                let message = NSLocalizedString("UA_Copied_To_Clipboard", tableName: "UAPushUI", comment: "Copied to clipboard string")
                
                let alert = UIAlertController(title: nil, message: message, preferredStyle: UIAlertController.Style.alert)
                let buttonTitle = NSLocalizedString("UA_OK", tableName: "UAPushUI", comment: "OK button string")
                
                let okAction = UIAlertAction(title: buttonTitle, style: UIAlertAction.Style.default, handler: { (action: UIAlertAction) in
                    self.dismiss(animated: true, completion: nil)
                })
                
                alert.addAction(okAction)
                
                self.present(alert, animated: true, completion: nil)
            }
            break
        case sdkVersionCell:
            UIPasteboard.general.string = UAirshipVersion.get()
            
            let message = NSLocalizedString("UA_Copied_To_Clipboard", tableName: "UAPushUI", comment: "Copied to clipboard string")
            
            let alert = UIAlertController(title: nil, message: message, preferredStyle: UIAlertController.Style.alert)
            let buttonTitle = NSLocalizedString("UA_OK", tableName: "UAPushUI", comment: "OK button string")
            
            let okAction = UIAlertAction(title: buttonTitle, style: UIAlertAction.Style.default, handler: { (action: UIAlertAction) in
                self.dismiss(animated: true, completion: nil)
            })
            
            alert.addAction(okAction)
            
            self.present(alert, animated: true, completion: nil)
            break
        default:
            break
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
