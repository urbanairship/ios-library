/* Copyright Airship and Contributors */

import AirshipKit
import UIKit

class PushSettingsViewController: UITableViewController, UARegistrationDelegate {

    @IBOutlet weak var pushEnabledCell: UITableViewCell!
    @IBOutlet weak var channelIDCell: UITableViewCell!
    @IBOutlet weak var namedUserCell: UITableViewCell!
    @IBOutlet weak var tagsCell: UITableViewCell!
    @IBOutlet weak var analyticsEnabledCell: UITableViewCell!
    @IBOutlet weak var locationEnabledCell: UITableViewCell!

    var pushEnabled: Bool = false
    var namedUser: String = "Not Set"
    var tags: Array = ["Not Set"]
    var analytics: Bool = false
    var locationEnabled: Bool = false

    var defaultDetailVC:UIViewController!
    var namedUserDetailVC:UIViewController!
    var tagsDetailVC:UIViewController!

    override func viewDidLoad() {
        super.viewDidLoad()

        UAirship.push().registrationDelegate = self

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(PushSettingsViewController.refreshView),
            name: NSNotification.Name(UAChannelUpdatedEvent),
            object: nil);

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(PushSettingsViewController.refreshView),
            name: NSNotification.Name("refreshView"),
            object: nil);

        pushEnabled = UAirship.push().userPushNotificationsEnabled
        locationEnabled = UAirship.shared()?.locationProviderDelegate?.isLocationUpdatesEnabled ?? false
        analytics = UAirship.analytics().isEnabled

        refreshView()

        locationEnabledCell.textLabel?.text = "Enable Location"
        locationEnabledCell.detailTextLabel?.text = "Enable Location When In Use"

        defaultDetailVC = self.storyboard!.instantiateViewController(withIdentifier: "defaultDetailVC")
        namedUserDetailVC = self.storyboard!.instantiateViewController(withIdentifier: "namedUserDetailVC");
        tagsDetailVC = self.storyboard!.instantiateViewController(withIdentifier: "tagsDetailVC")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshView()
    }

    @objc func refreshView() {
        channelIDCell?.detailTextLabel?.text = UAirship.channel().identifier ?? "Not Set"

        analyticsEnabledCell.accessoryType = analytics ? .checkmark : .none
        locationEnabledCell.accessoryType = locationEnabled ? .checkmark : .none

        namedUserCell.detailTextLabel?.text = UAirship.namedUser().identifier ?? "Not Set"
        tagsCell.detailTextLabel?.text = (UAirship.channel().tags.count > 0) ?
            UAirship.channel().tags.joined(separator: ", ") : "Not Set"
    }

    override func tableView(_ tableView: UITableView, didUpdateFocusIn context: UITableViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {

        guard let focusedSection = context.nextFocusedIndexPath?.section,
            let focusedRow = context.nextFocusedIndexPath?.row else {
                return
        }

        let tagsIndexPath = tableView.indexPath(for: tagsCell)
        let namedUserIndexPath = tableView.indexPath(for: namedUserCell)

        switch (focusedSection, focusedRow) {
        case (tagsIndexPath!.section, tagsIndexPath!.row) :
            self.showDetailViewController(tagsDetailVC, sender: self)
            break
        case (namedUserIndexPath!.section, namedUserIndexPath!.row) :
            self.showDetailViewController(namedUserDetailVC, sender: self)
            break
        default:
            self.showDetailViewController(defaultDetailVC, sender: self)
            break
        }

    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let pushEnabledIndexPath = tableView.indexPath(for: pushEnabledCell)
        let analyticsEnabledIndexPath = tableView.indexPath(for: analyticsEnabledCell)
        let locationEnabledIndexPath = tableView.indexPath(for: locationEnabledCell)

        switch (indexPath.section, indexPath.row) {
        case (pushEnabledIndexPath!.section, pushEnabledIndexPath!.row) :
            if (!UAirship.push().userPromptedForNotifications) {
                UAirship.push().userPushNotificationsEnabled = true
            }
            break
        case (analyticsEnabledIndexPath!.section, analyticsEnabledIndexPath!.row) :
            analytics = !analytics;
            UAirship.analytics().isEnabled = analytics
            refreshView()
            break
        case (locationEnabledIndexPath!.section, locationEnabledIndexPath!.row) :
            locationEnabled = !locationEnabled;
            UAirship.shared()?.locationProviderDelegate?.isLocationUpdatesEnabled = locationEnabled
            refreshView()
            break
        default:
            break
        }
    }

    func notificationAuthorizedSettingsDidChange(_ options: UAAuthorizedNotificationSettings = []) {
        if (UAirship.push()?.authorizedNotificationSettings.rawValue == 0) {
            pushEnabledCell.detailTextLabel?.text = "Enable In System Settings"
            pushEnabledCell.accessoryType = .none
        } else {
            pushEnabledCell.detailTextLabel?.text = "Disable In System Settings"
            pushEnabledCell.accessoryType = .checkmark
        }
    }
}




