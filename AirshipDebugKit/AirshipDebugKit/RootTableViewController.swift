/* Copyright Urban Airship and Contributors */

import UIKit

class RootTableViewController: UITableViewController {
    @IBOutlet var deviceInfoTitle: UILabel!
    @IBOutlet var deviceInfoSubtitle: UILabel!
    @IBOutlet var deviceInfoCell: UITableViewCell!

    @IBOutlet var eventsTitle: UILabel!
    @IBOutlet var eventsSubtitle: UILabel!
    @IBOutlet var eventsCell: UITableViewCell!

    @IBOutlet var automationTitle: UILabel!
    @IBOutlet var automationSubtitle: UILabel!
    @IBOutlet var automationCell: UITableViewCell!

    func setTableViewTheme() {
        tableView.backgroundColor = ThemeManager.shared.currentTheme.Background;
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor:ThemeManager.shared.currentTheme.PrimaryText]
        navigationController?.navigationBar.barTintColor = ThemeManager.shared.currentTheme.NavigationBarBackground;
    }

    func localize() {
        navigationController?.navigationBar.topItem?.title = "ua_debug_kit_title".localized()

        deviceInfoTitle.text = "ua_device_info_title".localized()
        deviceInfoSubtitle.text = "ua_device_info_subtitle".localized()
        eventsTitle.text = "ua_events_title".localized()
        eventsSubtitle.text = "ua_events_subtitle".localized()
        automationTitle.text = "ua_automation_title".localized()
        automationSubtitle.text = "ua_automation_subtitle".localized()
    }

    func setCellTheme() {
        deviceInfoCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        deviceInfoTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        deviceInfoSubtitle.textColor = ThemeManager.shared.currentTheme.SecondaryText

        eventsCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        eventsTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        eventsSubtitle.textColor = ThemeManager.shared.currentTheme.SecondaryText

        automationCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        automationTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        automationSubtitle.textColor = ThemeManager.shared.currentTheme.SecondaryText

    }

    override func viewDidLoad() {
        super.viewDidLoad()

        localize()
        setTableViewTheme()
        setCellTheme()
    }
}
