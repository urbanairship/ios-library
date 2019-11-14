/* Copyright Airship and Contributors */

import UIKit

#if canImport(AirshipCore)
import AirshipCore
#endif

import MapKit

class EventsDetailTableViewController: UITableViewController {

    @IBOutlet private weak var typeTitleLabel: UILabel!
    @IBOutlet private weak var typeCell: UITableViewCell!
    @IBOutlet private weak var typeLabel: UILabel!

    @IBOutlet private weak var timeCell: UITableViewCell!
    @IBOutlet private weak var timeTitleLabel: UILabel!
    @IBOutlet private weak var timeLabel: UILabel!

    @IBOutlet private weak var dataCell: UITableViewCell!
    @IBOutlet private weak var dataLabel: UILabel!
    @IBOutlet private weak var dataTitleLabel: UILabel!

    func setCellTheme() {
        typeCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        timeCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        dataCell.backgroundColor = ThemeManager.shared.currentTheme.Background

        typeTitleLabel.textColor = ThemeManager.shared.currentTheme.PrimaryText
        timeTitleLabel.textColor = ThemeManager.shared.currentTheme.PrimaryText
        dataTitleLabel.textColor = ThemeManager.shared.currentTheme.PrimaryText

        typeLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText
        timeLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText
        dataLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        refresh()
    }

    func setTableViewTheme() {
        tableView.backgroundColor = ThemeManager.shared.currentTheme.Background;
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor:ThemeManager.shared.currentTheme.NavigationBarText]
        navigationController?.navigationBar.barTintColor = ThemeManager.shared.currentTheme.NavigationBarBackground;
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.backgroundColor = ThemeManager.shared.currentTheme.Background
        setCellTheme()
        setTableViewTheme()
    }

    var event: Event? {
        didSet {
            refresh()
        }
    }

    func refresh() {
        if let event = event {
            if let typeLabel = typeLabel {
                typeLabel.text = event.eventType
            }

            if let timeLabel = timeLabel {
                timeLabel.text = event.time.toPrettyDateString()
            }

            if let dataLabel = dataLabel {
                dataLabel.text = event.data
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return event?.eventID
        }

        return nil
    }
}

