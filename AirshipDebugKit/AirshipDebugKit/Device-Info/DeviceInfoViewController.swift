/* Copyright 2018 Urban Airship and Contributors */

import UIKit
import AirshipKit

class DeviceInfoViewController: UITableViewController {
    
    @IBOutlet weak var pushEnabledCell: UITableViewCell!
    @IBOutlet weak var channelIDCell: UITableViewCell!
    @IBOutlet weak var namedUserCell: UITableViewCell!
    @IBOutlet weak var tagsCell: UITableViewCell!
    @IBOutlet weak var associatedIdentifiersCell:UITableViewCell!

    @IBOutlet weak var sdkVersionCell: UITableViewCell!

    @IBOutlet weak var locationEnabledCell: UITableViewCell!

    @IBOutlet weak var pushEnabledSwitch: UISwitch!
    @IBOutlet weak var locationEnabledSwitch: UISwitch!
    @IBOutlet weak var analyticsSwitch: UISwitch!
    
    @IBOutlet weak var pushSettingsLabel: UILabel!
    @IBOutlet weak var pushSettingsSubtitleLabel: UILabel!
    @IBOutlet weak var locationEnabledLabel: UILabel!
    @IBOutlet weak var locationEnabledSubtitleLabel: UILabel!
    
    @IBOutlet weak var channelIDSubtitleLabel: UILabel!
    @IBOutlet weak var namedUserSubtitleLabel: UILabel!
    @IBOutlet weak var tagsSubtitleLabel: UILabel!
    @IBOutlet weak var versionSubtitleLabel: UILabel!
    
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
        
        locationEnabledLabel.text = NSLocalizedString("UA_Location_Enabled", tableName: "UAPushUI", comment: "Location Enabled label")
        locationEnabledSubtitleLabel.text = NSLocalizedString("UA_Location_Enabled_Detail", tableName: "UAPushUI", comment: "Enable GPS and WIFI Based Location detail label")
        pushEnabledSwitch.isOn = UAirship.push().userPushNotificationsEnabled
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated);
        
        // Simplified screen tracking name for easy testing of message triggers
        UAirship.analytics()?.trackScreen("DeviceInfoViewController")
        
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
        
        versionSubtitleLabel.text = UAirshipVersion.get()
        
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
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard (tableView.indexPath(for: pushEnabledCell) != nil
            && tableView.indexPath(for: channelIDCell) != nil
            && tableView.indexPath(for: sdkVersionCell) != nil) else {
            return
        }
        
        switch (indexPath.section, indexPath.row) {
        case ((tableView.indexPath(for: pushEnabledCell)! as NSIndexPath).section, (tableView.indexPath(for: pushEnabledCell)! as NSIndexPath).row) :
            // redirect click on push enabled cell to system settings
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,options: [:],completionHandler: nil)
            break
        case ((tableView.indexPath(for: channelIDCell)! as NSIndexPath).section, (tableView.indexPath(for: channelIDCell)! as NSIndexPath).row) :
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
        case ((tableView.indexPath(for: sdkVersionCell)! as NSIndexPath).section, (tableView.indexPath(for: sdkVersionCell)! as NSIndexPath).row) :
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
    }
}
