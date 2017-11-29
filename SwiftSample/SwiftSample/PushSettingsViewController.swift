/* Copyright 2017 Urban Airship and Contributors */

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


        // iOS 8 & 9 - user notifications cannot be disabled, so remove switch and link to system settings
        if (!ProcessInfo().isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 10, minorVersion: 0, patchVersion: 0)) && UAirship.push().userPushNotificationsEnabled) {
            pushSettingsLabel.text = NSLocalizedString("UA_Push_Settings_Title", tableName: "UAPushUI", comment: "System Push Settings Label")

            pushSettingsSubtitleLabel.text = pushTypeString()
            pushEnabledSwitch?.isHidden = true
            pushEnabledCell.selectionStyle = .default
        }
    }

    func pushTypeString () -> String {

        let types = UAirship.push().authorizedNotificationOptions;

        var typeArray: [String] = []

        if (types.contains(.alert)) {
            typeArray.append(NSLocalizedString("UA_Notification_Type_Alerts", tableName: "UAPushUI", comment: "Alerts"))
        }

        if (types.contains(.badge)){
            typeArray.append(NSLocalizedString("UA_Notification_Type_Badges", tableName: "UAPushUI", comment: "Badges"))
        }

        if (types.contains(.sound)) {
            typeArray.append(NSLocalizedString("UA_Notification_Type_Sounds", tableName: "UAPushUI", comment: "Sounds"))
        }

        if (typeArray.count == 0) {
            return NSLocalizedString("UA_Push_Settings_Link_Disabled_Title", tableName: "UAPushUI", comment: "Pushes Currently Disabled")
        }

        return typeArray.joined(separator: ", ")
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch ((indexPath as NSIndexPath).section, (indexPath as NSIndexPath).row) {
            case ((tableView.indexPath(for: pushEnabledCell)! as NSIndexPath).section, (tableView.indexPath(for: pushEnabledCell)! as NSIndexPath).row) :

                if #available(iOS 10,*) {
                    // iOS 10 or later - do nothing
                } else {
                    // iOS 8 & 9 - redirect push enabled cell to system settings
                    if (UAirship.push().userPushNotificationsEnabled) {
                        UIApplication.shared.openURL(URL(string: UIApplicationOpenSettingsURLString)!)
                    }
                }

                break
            case ((tableView.indexPath(for: channelIDCell)! as NSIndexPath).section, (tableView.indexPath(for: channelIDCell)! as NSIndexPath).row) :
                if ((UAirship.push().channelID) != nil) {
                    UIPasteboard.general.string = channelIDSubtitleLabel?.text
                    showCopyMessage()
                }
                break
            default:
                break
        }
    }
    
    func showCopyMessage () {
        let message = UAInAppMessage()
        message.alert = NSLocalizedString("UA_Copied_To_Clipboard", tableName: "UAPushUI", comment: "Copied to clipboard string")
        message.position = UAInAppMessagePosition.top
        message.duration = 1.5
        message.primaryColor = UIColor(red: 255/255, green: 200/255, blue: 40/255, alpha: 1)
        message.secondaryColor = UIColor(red: 0/255, green: 105/255, blue: 143/255, alpha: 1)
        UAirship.inAppMessaging().display(message)
    }
}




