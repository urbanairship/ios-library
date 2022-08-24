/* Copyright Airship and Contributors */

import UIKit

#if canImport(AirshipCore)
import AirshipCore
import AirshipAutomation
#elseif canImport(AirshipKit)
import AirshipKit
#endif


class AutomationDetailCell: UITableViewCell {
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var subtitle: UILabel!

    @IBOutlet var titleTopConstraint: NSLayoutConstraint!

    override func layoutSubviews() {
        super.layoutSubviews()

        if isSubtitleValid(subtitle:subtitle.text) {
            titleTopConstraint.priority = UILayoutPriority(rawValue: 900)
        } else {
            titleTopConstraint.priority = UILayoutPriority(rawValue: 100)
        }

        layoutIfNeeded()
    }

    func isSubtitleValid(subtitle:String?) -> Bool {
        guard let subtitle = subtitle else { return false }

        return !subtitle.isEmpty
    }
}

class AutomationDetailButtonCell: UITableViewCell {
    @IBOutlet weak var title: UILabel!
}

class AutomationDetailViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet var tableView: UITableView!
    
    public static let segueID = "AutomationDetailSegue"

    private let defaultCellHeight:CGFloat = 44

    var collapsedCellPaths:[IndexPath] = []

    /* The UASchedule to be displayed */
    public var schedule : UASchedule?

    private let inAppAutomation = InAppAutomation.shared!


    /* Section
     * Note: Number of sections and sections for row are defined in their respective
     * table view data source methods
     */
    let scheduleSection = 0

    // Indexes section 0
    let identifierIdx = IndexPath(row: 0, section: 0),
    startIdx = IndexPath(row: 1, section: 0),
    endIdx = IndexPath(row: 2, section: 0),
    priorityIdx = IndexPath(row: 3, section: 0),
    limitIdx = IndexPath(row: 4, section: 0),
    triggersIdx = IndexPath(row: 5, section: 0),
    delayIdx = IndexPath(row: 6, section: 0),
    editGracePeriodIdx = IndexPath(row: 7, section: 0),
    intervalIdx = IndexPath(row: 8, section: 0),
    isValidIdx = IndexPath(row: 9, section: 0),
    audienceIdx = IndexPath(row: 10, section: 0),
    scheduleDataIdx =  IndexPath(row: 11, section: 0),
    payloadIdx =  IndexPath(row: 12, section: 0),
    cancelScheduleIdx =  IndexPath(row: 13, section: 0)

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self

        setTableViewTheme()
    }

    func setTableViewTheme() {
        tableView.backgroundColor = ThemeManager.shared.currentTheme.Background;
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case scheduleSection:
            return 14
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerView = view as? UITableViewHeaderFooterView {
            headerView.textLabel?.textColor = ThemeManager.shared.currentTheme.WidgetTint
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case scheduleSection:
            return createScheduleCell(indexPath)
        default:
            break
        }

        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return action == #selector(copy(_:))
    }

    func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
        if action == #selector(copy(_:)) {
            var copiedText : String?

            let cell = tableView.cellForRow(at: indexPath) as! AutomationDetailCell

            switch indexPath {
            case identifierIdx:
                copiedText = cell.subtitle.text
            default:
                break
            }
            if let copiedText = copiedText {
                let pasteboard = UIPasteboard.general
                pasteboard.string = copiedText
            }
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath {
        case triggersIdx:
            performSegue(withIdentifier: "TriggersSegue", sender: indexPath)
        case delayIdx:
            // Was this left unfinished? It has a disclosure but no segue on next branch
            break
        case cancelScheduleIdx:
            // Cancel Schedule
            if let schedule = schedule {
                let alert = UIAlertController(title: nil, message: "ua_cancelSchedule_alert_message".localized(), preferredStyle: UIAlertController.Style.alert)
                let cancelScheduleAction = UIAlertAction(title: "ua_cancelSchedule_alert_button".localized(), style: UIAlertAction.Style.default, handler: { (action: UIAlertAction) in
                    self.inAppAutomation.cancelSchedule(withID: schedule.identifier)
                    self.navigationController?.popViewController(animated: true)
                })
                alert.addAction(cancelScheduleAction)
                alert.addAction(UIAlertAction(title: "ua_cancelSchedule_alert_cancel_button".localized(), style: UIAlertAction.Style.cancel, handler: nil))

                self.present(alert, animated: true, completion: nil)
            }
        case audienceIdx:
            performSegue(withIdentifier: AudienceDetailViewController.segueID, sender: indexPath)
        case scheduleDataIdx:
            if schedule is InAppMessageSchedule {
                performSegue(withIdentifier: InAppMessageDetailViewController.segueID, sender: indexPath)
            } else if schedule is ActionSchedule {
                performSegue(withIdentifier: ActionDetailViewController.segueID, sender: indexPath)
            } else if schedule is DeferredSchedule {
                performSegue(withIdentifier: DeferredDetailViewController.segueID, sender: indexPath)
            }
        default:
            break
        }
    }

    func defaultAutomationDetailCell(_ indexPath:IndexPath) -> AutomationDetailCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AutomationDetailCell", for: indexPath) as! AutomationDetailCell

        // Remove storyboard placeholders
        cell.title.text = nil
        cell.subtitle.text = nil
        cell.subtitle.textColor = ThemeManager.shared.currentTheme.SecondaryText
        cell.backgroundColor = ThemeManager.shared.currentTheme.Background
        cell.title.textColor = ThemeManager.shared.currentTheme.PrimaryText
        // hide accessory by default
        cell.accessoryType = .none

        return cell
    }

    func createScheduleCell(_ indexPath:IndexPath) -> UITableViewCell {
        // Handle button and payload cells separately
        
        guard let schedule = schedule else { return UITableViewCell() }
        
        switch indexPath {
        case cancelScheduleIdx:
            let cell = tableView.dequeueReusableCell(withIdentifier: "AutomationDetailButtonCell", for: indexPath) as! AutomationDetailButtonCell
            cell.title.text = "ua_cancel_schedule".localized()
            cell.title.textColor = ThemeManager.shared.currentTheme.PrimaryText
            cell.backgroundColor = ThemeManager.shared.currentTheme.ButtonBackground
            return cell
        default:
            break
        }
        
        let cell = defaultAutomationDetailCell(indexPath)

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]

        switch indexPath {
        case identifierIdx:
            cell.title.text = "ua_scheduleinfo_identifier".localized()
            cell.subtitle.text = schedule.identifier
        case startIdx:
            cell.title.text = "ua_scheduleinfo_start".localized()
            if let start = schedule.start {
                cell.subtitle.text = dateFormatter.string(from: start)
            }
        case endIdx:
            cell.title.text = "ua_scheduleinfo_end".localized()
            if let end = schedule.end {
                cell.subtitle.text = dateFormatter.string(from: end)
            }
        case priorityIdx:
            cell.title.text = "ua_scheduleinfo_priority".localized()
            cell.subtitle.text = String(schedule.priority)
        case limitIdx:
            cell.title.text = "ua_scheduleinfo_limit".localized()
            cell.subtitle.text = String(schedule.limit)
        case triggersIdx:
            cell.title.text = "ua_scheduleinfo_triggers".localized()
            cell.accessoryType = .disclosureIndicator
            cell.subtitle.text = String(schedule.triggers.count)
        case delayIdx:
            cell.title.text = "ua_scheduleinfo_delay".localized()
            cell.accessoryType = .disclosureIndicator
            if let delay = schedule.delay {
                cell.subtitle.text = String(delay.seconds)
            } else {
                collapsedCellPaths.addObjectIfNew(delayIdx)
            }
        case editGracePeriodIdx:
            cell.title.text = "ua_scheduleinfo_editgraceperiod".localized()
            cell.subtitle.text = "\(schedule.editGracePeriod.descriptionWithUnits)"
        case intervalIdx:
            cell.title.text = "ua_scheduleinfo_interval".localized()
            cell.subtitle.text = "\(schedule.interval.descriptionWithUnits)"
        case isValidIdx:
            cell.title.text = "ua_scheduleinfo_isvalid".localized()
            cell.subtitle.text = (schedule.isValid) ? "ua_yesno_yes".localized() : "ua_yesno_no".localized()
        case audienceIdx:
            cell.title.text = "ua_message_audience".localized()
            cell.subtitle.text = ""
            cell.accessoryType = .disclosureIndicator
            if schedule.audience == nil {
                collapsedCellPaths.addObjectIfNew(audienceIdx)
            }
        case scheduleDataIdx:
            cell.title.text = "ua_scheduleinfo_schedule_data".localized()
            cell.accessoryType = .disclosureIndicator
        case payloadIdx:
            cell.title.text = "ua_scheduleinfo_schedule_payload".localized()
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: schedule.metadata)
                cell.subtitle.text = String(data: jsonData, encoding: .utf8)?.prettyJSONFormat()
                cell.subtitle.sizeToFit()
                cell.subtitle.lineBreakMode = NSLineBreakMode.byWordWrapping
            } catch {
                AirshipLogger.error("JSON parsing failed \(error)")
            }
        default:
            break
        }

        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if collapsedCellPaths.contains(indexPath) {
            return 0
        }
        
        if indexPath == payloadIdx {
            return UITableView.automaticDimension
        }
        
        return 44
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case scheduleSection:
            return "ua_schedule_title".localized()
        default:
            return "ua_displaycontent_title_unknown".localized()
        }
    }
    
    func getDisplayContentTitle() -> String? {
        return "ua_displaycontent_title_unknown".localized()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        super.prepare(for: segue, sender: sender)

        guard let selectedIdx = sender as? IndexPath else {
            fatalError("Unexpected sender: \(sender ?? "unknown sender")")
        }

        switch(segue.identifier ?? "") {
        case "ShowScheduleDelayDetail":
            // TODO - implement schedule delay detail view
            print("UNIMPLEMENTED")
        case TriggerTableViewController.segueID:
            guard let triggersTableViewController = segue.destination as? TriggerTableViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }

            switch (selectedIdx) {
            case triggersIdx:
                triggersTableViewController.triggers = schedule?.triggers
            default:
                print("ERROR: unexpected triggers cell selected")
            }
        case AudienceDetailViewController.segueID:
            guard let audienceDetailViewController = segue.destination as? AudienceDetailViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }

            switch (selectedIdx) {
            case audienceIdx:
                audienceDetailViewController.audience = schedule?.audience
            default:
                print("ERROR: unexpected audience info cell selected")
            }
        case InAppMessageDetailViewController.segueID:
            guard let inAppMessageDetailViewController = segue.destination as? InAppMessageDetailViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }

            switch (selectedIdx) {
            case scheduleDataIdx:
                inAppMessageDetailViewController.schedule = schedule as? InAppMessageSchedule
            default:
                print("ERROR: unexpected schedule data info cell selected")
            }
        case ActionDetailViewController.segueID:
            guard let actionDetailViewController = segue.destination as? ActionDetailViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }

            switch (selectedIdx) {
            case scheduleDataIdx:
                actionDetailViewController.schedule = schedule as? ActionSchedule
            default:
                print("ERROR: unexpected schedule data info cell selected")
            }
        case DeferredDetailViewController.segueID:
            guard let deferredDetailViewController = segue.destination as? DeferredDetailViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }

            switch (selectedIdx) {
            case scheduleDataIdx:
                deferredDetailViewController.schedule = schedule as? DeferredSchedule
            default:
                print("ERROR: unexpected schedule data info cell selected")
            }
        default:
            return
        }
    }
}

extension TimeInterval {
    var seconds: TimeInterval { return self }
    var minutes: TimeInterval { return self / (60.0) }
    var hours:   TimeInterval { return self / (60.0 * 60.0) }
    var days:    TimeInterval { return self / (60.0 * 60.0 * 24.0) }
    var weeks:   TimeInterval { return self / (60.0 * 60.0 * 24.0 * 7.0) }
    var months:  TimeInterval { return self / (60.0 * 60.0 * 24.0 * 30.4375) }
    var years:   TimeInterval { return self / (60.0 * 60.0 * 24.0 * 365.25) }
    var descriptionWithUnits: String {
        if (self.years > 1) {
            return String(format: "ua_timeinterval_description_years".localized(), self.years)
        }
        if (self.months > 1) {
            return String(format: "ua_timeinterval_description_months".localized(), self.months)
        }
        if (self.weeks > 1) {
            return String(format: "ua_timeinterval_description_weeks".localized(), self.weeks)
        }
        if (self.days > 1) {
            return String(format: "ua_timeinterval_description_days".localized(), self.days)
        }
        if (self.hours > 1) {
            return String(format: "ua_timeinterval_description_hours".localized(), self.hours)
        }
        if (self.minutes > 1) {
            return String(format: "ua_timeinterval_description_minutes".localized(), self.minutes)
        }
        return String(format: "ua_timeinterval_description_seconds".localized(), self.seconds)
    }
}

extension Array where Element: Equatable {
    mutating func addObjectIfNew(_ item: Element) {
        if !contains(item) {
            append(item)
        }
    }
}
