/* Copyright Airship and Contributors */

import AirshipCore
import UIKit
import Combine

class PushSettingsViewController: UITableViewController, RegistrationDelegate {
    
    @IBOutlet weak var pushEnabledCell: UITableViewCell!
    @IBOutlet weak var channelIDCell: UITableViewCell!
    @IBOutlet weak var namedUserCell: UITableViewCell!
    @IBOutlet weak var tagsCell: UITableViewCell!
    @IBOutlet weak var analyticsEnabledCell: UITableViewCell!

    var pushEnabled: Bool = false
    var namedUser: String = "Not Set"
    var tags: Array = ["Not Set"]
    var analytics: Bool = false
    private var subscriptions: Set<AnyCancellable> = Set()
    var defaultDetailVC: UIViewController!
    var namedUserDetailVC: UIViewController!
    var tagsDetailVC: UIViewController!

    override func viewDidLoad() {
        super.viewDidLoad()

        Airship.contact.namedUserIDPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] namedUserID in
                self?.namedUserCell.detailTextLabel?.text =
                namedUserID ?? "Not Set"
            }.store(in: &self.subscriptions)

        Airship.push.registrationDelegate = self

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(PushSettingsViewController.refreshView),
            name: AirshipNotifications.ChannelCreated.name,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(PushSettingsViewController.refreshView),
            name: NSNotification.Name("refreshView"),
            object: nil
        )

        pushEnabled = Airship.push.userPushNotificationsEnabled
        analytics = Airship.privacyManager.isEnabled(.analytics)

        refreshView()

        defaultDetailVC = self.storyboard!
            .instantiateViewController(withIdentifier: "defaultDetailVC")
        namedUserDetailVC = self.storyboard!
            .instantiateViewController(withIdentifier: "namedUserDetailVC")
        tagsDetailVC = self.storyboard!
            .instantiateViewController(withIdentifier: "tagsDetailVC")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshView()
    }

    @objc func refreshView() {
        channelIDCell?.detailTextLabel?.text =
            Airship.channel.identifier ?? "Not Set"

        analyticsEnabledCell.accessoryType = analytics ? .checkmark : .none

        tagsCell.detailTextLabel?.text =
            (Airship.channel.tags.count > 0)
            ? Airship.channel.tags.joined(separator: ", ") : "Not Set"
    }

    override func tableView(
        _ tableView: UITableView,
        didUpdateFocusIn context: UITableViewFocusUpdateContext,
        with coordinator: UIFocusAnimationCoordinator
    ) {

        guard let focusedSection = context.nextFocusedIndexPath?.section,
            let focusedRow = context.nextFocusedIndexPath?.row
        else {
            return
        }

        let tagsIndexPath = tableView.indexPath(for: tagsCell)
        let namedUserIndexPath = tableView.indexPath(for: namedUserCell)

        switch (focusedSection, focusedRow) {
        case (tagsIndexPath!.section, tagsIndexPath!.row):
            self.showDetailViewController(tagsDetailVC, sender: self)
            break
        case (namedUserIndexPath!.section, namedUserIndexPath!.row):
            self.showDetailViewController(namedUserDetailVC, sender: self)
            break
        default:
            self.showDetailViewController(defaultDetailVC, sender: self)
            break
        }

    }

    override func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        tableView.deselectRow(at: indexPath, animated: true)

        let pushEnabledIndexPath = tableView.indexPath(for: pushEnabledCell)
        let analyticsEnabledIndexPath = tableView.indexPath(
            for: analyticsEnabledCell
        )

        switch (indexPath.section, indexPath.row) {
        case (pushEnabledIndexPath!.section, pushEnabledIndexPath!.row):
            if !Airship.push.userPromptedForNotifications {
                Airship.push.userPushNotificationsEnabled = true
            }
            break
        case (
            analyticsEnabledIndexPath!.section, analyticsEnabledIndexPath!.row
        ):
            analytics = !analytics
            if analytics {
                Airship.privacyManager.enableFeatures(.analytics)
            } else {
                Airship.privacyManager.disableFeatures(.analytics)
            }
            refreshView()
            break
        default:
            break
        }
    }

    func notificationAuthorizedSettingsDidChange(
        _ options: UAAuthorizedNotificationSettings = []
    ) {
        if Airship.push.authorizedNotificationSettings.rawValue == 0 {
            pushEnabledCell.detailTextLabel?.text = "Enable In System Settings"
            pushEnabledCell.accessoryType = .none
        } else {
            pushEnabledCell.detailTextLabel?.text = "Disable In System Settings"
            pushEnabledCell.accessoryType = .checkmark
        }
    }
}
