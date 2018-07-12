/* Copyright 2018 Urban Airship and Contributors */

import AirshipKit
import UIKit

class PushSettingsViewController: UITableViewController {

    @IBOutlet var pushEnabledCell: UITableViewCell!
    @IBOutlet var channelIDCell: UITableViewCell!
    @IBOutlet var namedUserCell: UITableViewCell!
    @IBOutlet var tagsCell: UITableViewCell!
    @IBOutlet var locationEnabledCell: UITableViewCell!

    @IBOutlet var pushEnabledSwitch: UISwitch!
    @IBOutlet var locationEnabledSwitch: UISwitch!
    @IBOutlet var analyticsSwitch: UISwitch!

    @IBOutlet var pushSettingsLabel: UILabel!
    @IBOutlet var pushSettingsSubtitleLabel: UILabel!
    @IBOutlet var locationEnabledLabel: UILabel!
    @IBOutlet var locationEnabledSubtitleLabel: UILabel!
    @IBOutlet var channelIDSubtitleLabel: UILabel!
    @IBOutlet var namedUserSubtitleLabel: UILabel!
    @IBOutlet var tagsSubtitleLabel: UILabel!

    @IBAction func switchValueChanged(_ sender: UISwitch) {

        // Only allow disabling user notifications on iOS 10+
        if (ProcessInfo().isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 10, minorVersion: 0, patchVersion: 0))) {
            UAirship.push().userPushNotificationsEnabled = pushEnabledSwitch.isOn
        } else if (pushEnabledSwitch.isOn) {
            UAirship.push().userPushNotificationsEnabled = true
        }

        UAirship.location().isLocationUpdatesEnabled = locationEnabledSwitch.isOn
        UAirship.shared().analytics.isEnabled = analyticsSwitch.isOn
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(PushSettingsViewController.refreshView),
            name: NSNotification.Name("channelIDUpdated"),
            object: nil);

        // Initialize switches
        locationEnabledSwitch.isOn = UAirship.location().isLocationUpdatesEnabled
        analyticsSwitch.isOn = UAirship.shared().analytics.isEnabled

        // add observer to didBecomeActive to update upon retrun from system settings screen
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(PushSettingsViewController.didBecomeActive),
            name: NSNotification.Name.UIApplicationDidBecomeActive,
            object: nil)

        locationEnabledLabel.text = NSLocalizedString("UA_Location_Enabled", tableName: "UAPushUI", comment: "Location Enabled label")
        locationEnabledSubtitleLabel.text = NSLocalizedString("UA_Location_Enabled_Detail", tableName: "UAPushUI", comment: "Enable GPS and WIFI Based Location detail label")
    }

    // this is necessary to update the view when returning from the system settings screen
    @objc func didBecomeActive () {
        refreshView()
    }

    override func viewWillAppear(_ animated: Bool) {
        refreshView()
    }

    @objc func refreshView() {
        pushEnabledSwitch.isOn = UAirship.push().userPushNotificationsEnabled

        channelIDSubtitleLabel?.text = UAirship.push().channelID
        
        namedUserSubtitleLabel?.text = UAirship.namedUser().identifier == nil ? NSLocalizedString("None", tableName: "UAPushUI", comment: "None") : UAirship.namedUser().identifier

        if (UAirship.push().tags.count > 0) {
            self.tagsSubtitleLabel?.text = UAirship.push().tags.joined(separator: ", ")
        } else {
            self.tagsSubtitleLabel?.text = NSLocalizedString("None", tableName: "UAPushUI", comment: "None")
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

        if (settingsArray.count == 0) {
            return NSLocalizedString("UA_Push_Settings_Link_Disabled_Title", tableName: "UAPushUI", comment: "Pushes Currently Disabled")
        }

        return settingsArray.joined(separator: ", ")
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if ((indexPath as NSIndexPath).section == (tableView.indexPath(for: channelIDCell)! as NSIndexPath).section &&
            ((indexPath as NSIndexPath).row) == (tableView.indexPath(for: channelIDCell)! as NSIndexPath).row) {
                if ((UAirship.push().channelID) != nil) {
                    UIPasteboard.general.string = channelIDSubtitleLabel?.text
                    showCopyMessage()
                }
        }
    }
    
    func showCopyMessage () {
        let message = NSLocalizedString("UA_Copied_To_Clipboard", tableName: "UAPushUI", comment: "Copied to clipboard string")

        let alert = UIAlertController(title: nil, message: message, preferredStyle: UIAlertControllerStyle.alert)
        let buttonTitle = NSLocalizedString("UA_OK", tableName: "UAPushUI", comment: "OK button string")

        let okAction = UIAlertAction(title: buttonTitle, style: UIAlertActionStyle.default, handler: { (action: UIAlertAction) in
            self.dismiss(animated: true, completion: nil)
        })

        alert.addAction(okAction)

        self.present(alert, animated: true, completion: nil)
    }
}




