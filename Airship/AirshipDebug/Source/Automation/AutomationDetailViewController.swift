/* Copyright Airship and Contributors */

import UIKit

#if canImport(AirshipCore)
import AirshipCore
import AirshipAutomation
#elseif canImport(Airship)
import Airship
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

    private let inAppMessageManager = UAInAppMessageManager.shared()


    /* Section
     * Note: Number of sections and sections for row are defined in their respective
     * table view data source methods
     */
    let scheduleSection = 0,
    messageSection = 1,
    contentSection = 2

    // Indexes section 0
    private let identifierIdx = IndexPath(row: 0, section: 0),
    startIdx = IndexPath(row: 1, section: 0),
    endIdx = IndexPath(row: 2, section: 0),
    priorityIdx = IndexPath(row: 3, section: 0),
    limitIdx = IndexPath(row: 4, section: 0),
    triggersIdx = IndexPath(row: 5, section: 0),
    delayIdx = IndexPath(row: 6, section: 0),
    editGracePeriodIdx = IndexPath(row: 7, section: 0),
    intervalIdx = IndexPath(row: 8, section: 0),
    isValidIdx = IndexPath(row: 9, section: 0),
    cancelScheduleIdx =  IndexPath(row: 10, section: 0)

    // Indexes section 1
    private let messageIdentifierIdx = IndexPath(row: 0, section: 1),
    nameIdx = IndexPath(row: 1, section: 1),
    displayTypeIdx = IndexPath(row: 2, section: 1),
    audienceIdx = IndexPath(row: 3, section: 1),
    extrasIdx = IndexPath(row: 4, section: 1)

    // Indexes section 2
    private let placementIdx = IndexPath(row: 0, section: 2),
    contentLayoutIdx = IndexPath(row: 1, section: 2),
    headingIdx = IndexPath(row: 2, section: 2),
    bodyIdx = IndexPath(row: 3, section: 2),
    mediaIdx = IndexPath(row: 4, section: 2),
    urlIdx = IndexPath(row: 5, section: 2),
    buttonsIdx = IndexPath(row: 6, section: 2),
    footerIdx = IndexPath(row: 7, section: 2),
    actionsIdx = IndexPath(row: 8, section: 2),
    durationIdx = IndexPath(row: 9, section: 2),
    borderRadiusIdx = IndexPath(row: 10, section: 2),
    backgroundColorIdx = IndexPath(row: 11, section: 2),
    dismissButtonIdx = IndexPath(row: 12, section: 2),
    allowFullscreenIdx = IndexPath(row: 13, section: 2)

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self

        setTableViewTheme()
    }

    func setTableViewTheme() {
        tableView.backgroundColor = ThemeManager.shared.currentTheme.Background;
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor:ThemeManager.shared.currentTheme.NavigationBarText]
        navigationController?.navigationBar.barTintColor = ThemeManager.shared.currentTheme.NavigationBarBackground;
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case scheduleSection:
            return 11
        case messageSection:
            return 5
        case contentSection:
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
        case messageSection:
            return createMessageCell(indexPath)
        case contentSection:
            return createContentCell(indexPath)
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
            case messageIdentifierIdx:
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
                    self.inAppMessageManager?.cancelSchedule(withID: schedule.identifier)
                    self.navigationController?.popViewController(animated: true)
                })
                alert.addAction(cancelScheduleAction)
                alert.addAction(UIAlertAction(title: "ua_cancelSchedule_alert_cancel_button".localized(), style: UIAlertAction.Style.cancel, handler: nil))

                self.present(alert, animated: true, completion: nil)
            }
        case audienceIdx:
            performSegue(withIdentifier: AudienceDetailViewController.segueID, sender: indexPath)
        case extrasIdx:
            performSegue(withIdentifier: ExtrasDetailViewController.segueID, sender: indexPath)
        case headingIdx:
            performSegue(withIdentifier: TextInfoDetailViewController.segueID, sender: indexPath)
        case bodyIdx:
            performSegue(withIdentifier: TextInfoDetailViewController.segueID, sender: indexPath)
        case mediaIdx:
            performSegue(withIdentifier: MediaInfoDetailViewController.segueID, sender: indexPath)
        case buttonsIdx:
            performSegue(withIdentifier: ButtonsTableViewController.segueID, sender: indexPath)
        case footerIdx:
            performSegue(withIdentifier: TextInfoDetailViewController.segueID, sender: indexPath)
        default:
            break
        }
    }

    func defaultAutomationDetailCell(_ indexPath:IndexPath) -> AutomationDetailCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AutomationDetailCell", for: indexPath) as! AutomationDetailCell

        // Remove storyboary placeholders
        cell.title.text = nil
        cell.subtitle.text = nil

        cell.backgroundColor = ThemeManager.shared.currentTheme.Background
        cell.title.textColor = ThemeManager.shared.currentTheme.PrimaryText
        cell.subtitle.textColor = ThemeManager.shared.currentTheme.SecondaryText
        // hide accessory by default
        cell.accessoryType = .none

        return cell
    }

    func createContentCell(_ indexPath:IndexPath) -> UITableViewCell {
        guard let schedule = schedule else { return UITableViewCell() }

        let scheduleInfo = schedule.info as! UAInAppMessageScheduleInfo
        let message = scheduleInfo.message

        switch (message.displayType) {
        case .banner:
            let displayContent = message.displayContent as! UAInAppMessageBannerDisplayContent
            return createBannerContentCell(indexPath, displayContent: displayContent)
        case .fullScreen:
            let displayContent = message.displayContent as! UAInAppMessageFullScreenDisplayContent
            return createFullScreenContentCell(indexPath, displayContent: displayContent)
        case .modal:
            let displayContent = message.displayContent as! UAInAppMessageModalDisplayContent
            return createModalContentCell(indexPath, displayContent: displayContent)
        case .HTML:
            let displayContent = message.displayContent as! UAInAppMessageHTMLDisplayContent
            return createHTMLContentCell(indexPath, displayContent: displayContent)
        case .custom:  // TODO - IMPLEMENT
            let _ = message.displayContent as! UAInAppMessageCustomDisplayContent
        @unknown default:
            let cell = defaultAutomationDetailCell(indexPath)
            cell.title.text = "ua_displaycontent_unknown".localized()
            return cell
        }

        return UITableViewCell()
    }

    func createBannerContentCell(_ indexPath:IndexPath, displayContent:UAInAppMessageBannerDisplayContent) -> UITableViewCell {
        let cell = defaultAutomationDetailCell(indexPath)

        switch indexPath {
        case placementIdx:
            cell.title.text = "ua_displaycontent_placement".localized()

            let placement =  displayContent.placement

            var subtitle:String?
            switch placement {
            case .top:
                subtitle = "ua_displaycontent_placement_top".localized()
            case .bottom:
                subtitle = "ua_displaycontent_placement_bottom".localized()
            default:
                subtitle = nil
            }

            cell.subtitle.text = subtitle
        case contentLayoutIdx:
            cell.title.text = "ua_displaycontent_contentlayout".localized()

            var subtitle:String?
            switch displayContent.contentLayout {
            case .mediaLeft:
                subtitle = "ua_displaycontent_contentLayout_mediaLeft".localized()
            case .mediaRight:
                subtitle = "ua_displaycontent_contentLayout_mediaRight".localized()
            default:
                subtitle = nil
            }

            cell.subtitle.text = subtitle
        case headingIdx:
            cell.title.text = "ua_displaycontent_heading".localized()
            cell.subtitle.text = displayContent.heading?.text
            cell.accessoryType = .disclosureIndicator
        case bodyIdx:
            cell.title.text = "ua_displaycontent_body".localized()
            cell.subtitle.text = displayContent.body?.text
            cell.accessoryType = .disclosureIndicator
        case mediaIdx:
            cell.title.text = "ua_displaycontent_media".localized()
            cell.subtitle.text = descriptionForMedia(displayContent.media)
            cell.accessoryType = .disclosureIndicator
        case urlIdx:
            collapsedCellPaths.addObjectIfNew(urlIdx)
        case buttonsIdx:
            cell.title.text = "ua_displaycontent_buttons".localized()
            cell.subtitle.text = descriptionForButtons(displayContent.buttons, displayContent.buttonLayout)
            cell.accessoryType = .disclosureIndicator
            
            break
        case footerIdx:
            collapsedCellPaths.addObjectIfNew(footerIdx)
        case actionsIdx:
            cell.title.text = "ua_displaycontent_actions".localized()
            cell.subtitle.text = (displayContent.actions != nil) ? "ua_yesno_yes".localized() : "ua_yesno_no".localized()
        case durationIdx:
            cell.title.text = "ua_displaycontent_duration".localized()
            cell.subtitle.text = String(format: "ua_displaycontent_duration_format".localized(), displayContent.durationSeconds)
        case borderRadiusIdx:
            cell.title.text = "ua_displaycontent_borderradius".localized()
            cell.subtitle.text = "\(displayContent.borderRadiusPoints)"
        case backgroundColorIdx:
            cell.title.text = "ua_displaycontent_backgroundcolor".localized()
            cell.subtitle.text = descriptionForColor(displayContent.backgroundColor)
        case dismissButtonIdx:
            cell.title.text = "ua_displaycontent_dismissbuttoncolor".localized()
            cell.subtitle.text = descriptionForColor(displayContent.dismissButtonColor)
        case allowFullscreenIdx:
            collapsedCellPaths.addObjectIfNew(allowFullscreenIdx)
        default:
            break
        }

        return cell
    }

    func createFullScreenContentCell(_ indexPath:IndexPath, displayContent:UAInAppMessageFullScreenDisplayContent) -> UITableViewCell {
        let cell = defaultAutomationDetailCell(indexPath)

        switch indexPath {
        case placementIdx:
            collapsedCellPaths.addObjectIfNew(placementIdx)
        case contentLayoutIdx:
            cell.title.text = "ua_displaycontent_contentlayout".localized()

            var subtitle:String?
            switch displayContent.contentLayout {
            case .headerMediaBody:
                subtitle = "ua_displaycontent_contentLayout_headerMediaBody".localized()
            case .mediaHeaderBody:
                subtitle = "ua_displaycontent_contentLayout_mediaHeaderBody".localized()
            case .headerBodyMedia:
                subtitle = "ua_displaycontent_contentLayout_headerBodyMedia".localized()
            @unknown default:
                subtitle = "ua_displaycontent_contentLayout_unknown".localized()
            }

            cell.subtitle.text = subtitle
        case headingIdx:
            cell.title.text = "ua_displaycontent_heading".localized()
            if let heading = displayContent.heading?.text {
                cell.subtitle.text = heading
            } else {
                collapsedCellPaths.addObjectIfNew(headingIdx)
            }
            cell.accessoryType = .disclosureIndicator
        case bodyIdx:
            cell.title.text = "ua_displaycontent_body".localized()
            if let body = displayContent.body?.text {
                cell.subtitle.text = body
            } else {
                collapsedCellPaths.addObjectIfNew(bodyIdx)
            }
            cell.accessoryType = .disclosureIndicator
        case mediaIdx:
            cell.title.text = "ua_displaycontent_media".localized()
            cell.accessoryType = .disclosureIndicator

            if let description = descriptionForMedia(displayContent.media) {
                cell.subtitle.text = description
            } else {
                collapsedCellPaths.addObjectIfNew(mediaIdx)
            }
        case urlIdx:
            collapsedCellPaths.addObjectIfNew(urlIdx)
        case buttonsIdx:
            cell.title.text = "ua_displaycontent_buttons".localized()
            cell.subtitle.text = descriptionForButtons(displayContent.buttons, displayContent.buttonLayout)
            cell.accessoryType = .disclosureIndicator
        case footerIdx:
            cell.title.text = "ua_displaycontent_footer".localized()

            if let footer = displayContent.footer?.label.text {
                cell.subtitle.text = footer
            } else {
                collapsedCellPaths.addObjectIfNew(footerIdx)
            }

            cell.accessoryType = .disclosureIndicator
        case actionsIdx:
            collapsedCellPaths.addObjectIfNew(actionsIdx)
        case durationIdx:
            collapsedCellPaths.addObjectIfNew(durationIdx)
        case borderRadiusIdx:
            collapsedCellPaths.addObjectIfNew(borderRadiusIdx)
        case backgroundColorIdx:
            cell.title.text = "ua_displaycontent_backgroundcolor".localized()
            cell.subtitle.text = descriptionForColor(displayContent.backgroundColor)
        case dismissButtonIdx:
            cell.title.text = "ua_displaycontent_dismissbuttoncolor".localized()
            cell.subtitle.text = descriptionForColor(displayContent.dismissButtonColor)
        case allowFullscreenIdx:
            collapsedCellPaths.addObjectIfNew(allowFullscreenIdx)
        default:
            break
        }

        return cell
    }

    func createModalContentCell(_ indexPath:IndexPath, displayContent:UAInAppMessageModalDisplayContent) -> UITableViewCell {
        let cell = defaultAutomationDetailCell(indexPath)

        switch indexPath {
        case placementIdx:
            collapsedCellPaths.addObjectIfNew(placementIdx)
        case contentLayoutIdx:
            cell.title.text = "ua_displaycontent_contentlayout".localized()

            var subtitle:String?
            switch displayContent.contentLayout {
            case .headerMediaBody:
                subtitle = "ua_displaycontent_contentLayout_headerMediaBody".localized()
            case .mediaHeaderBody:
                subtitle = "ua_displaycontent_contentLayout_mediaHeaderBody".localized()
            case .headerBodyMedia:
                subtitle = "ua_displaycontent_contentLayout_headerBodyMedia".localized()
            @unknown default:
                subtitle = "ua_displaycontent_contentLayout_unknown".localized()
            }

            cell.subtitle.text = subtitle
        case headingIdx:
            cell.title.text = "ua_displaycontent_heading".localized()
            if let heading = displayContent.heading?.text {
                cell.subtitle.text = heading
            } else {
                collapsedCellPaths.addObjectIfNew(headingIdx)
            }
            cell.accessoryType = .disclosureIndicator
        case bodyIdx:
            cell.title.text = "ua_displaycontent_body".localized()
            if let body = displayContent.body?.text {
                cell.subtitle.text = body
            } else {
                collapsedCellPaths.addObjectIfNew(bodyIdx)
            }
            cell.accessoryType = .disclosureIndicator
        case mediaIdx:
            cell.title.text = "ua_displaycontent_media".localized()
            cell.accessoryType = .disclosureIndicator

            if let description = descriptionForMedia(displayContent.media) {
                cell.subtitle.text = description
            } else {
                collapsedCellPaths.addObjectIfNew(mediaIdx)
            }
        case urlIdx:
            collapsedCellPaths.addObjectIfNew(urlIdx)
        case buttonsIdx:
            cell.title.text = "ua_displaycontent_buttons".localized()
            cell.accessoryType = .disclosureIndicator

            if let description = descriptionForButtons(displayContent.buttons, displayContent.buttonLayout) {
                cell.subtitle.text = description
            } else {
                collapsedCellPaths.addObjectIfNew(buttonsIdx)
            }
        case footerIdx:
            cell.title.text = "ua_displaycontent_footer".localized()

            if let footer = displayContent.footer?.label.text {
                cell.subtitle.text = footer
            } else {
                collapsedCellPaths.addObjectIfNew(footerIdx)
            }

            cell.accessoryType = .disclosureIndicator
        case actionsIdx:
            collapsedCellPaths.addObjectIfNew(actionsIdx)
        case durationIdx:
            collapsedCellPaths.addObjectIfNew(durationIdx)
        case borderRadiusIdx:
            cell.title.text = "ua_displaycontent_borderradius".localized()
            cell.subtitle.text = "\(displayContent.borderRadiusPoints)"
        case backgroundColorIdx:
            cell.title.text = "ua_displaycontent_backgroundcolor".localized()
            cell.subtitle.text = descriptionForColor(displayContent.backgroundColor)
        case dismissButtonIdx:
            cell.title.text = "ua_displaycontent_dismissbuttoncolor".localized()
            cell.subtitle.text = descriptionForColor(displayContent.dismissButtonColor)
        case allowFullscreenIdx:
            cell.title.text = "ua_displaycontent_allowfullscreendisplay".localized()
            cell.subtitle.text = (displayContent.allowFullScreenDisplay) ? "ua_yesno_yes".localized() : "ua_yesno_no".localized()
        default:
            break
        }

        return cell
    }

    func createHTMLContentCell(_ indexPath:IndexPath, displayContent:UAInAppMessageHTMLDisplayContent) -> UITableViewCell {
        let cell = defaultAutomationDetailCell(indexPath)

        switch indexPath {
        case placementIdx:
            collapsedCellPaths.addObjectIfNew(placementIdx)
        case contentLayoutIdx:
            collapsedCellPaths.addObjectIfNew(contentLayoutIdx)
        case headingIdx:
            collapsedCellPaths.addObjectIfNew(headingIdx)
        case bodyIdx:
            collapsedCellPaths.addObjectIfNew(bodyIdx)
        case mediaIdx:
            collapsedCellPaths.addObjectIfNew(mediaIdx)
        case urlIdx:
            cell.title.text = "ua_displaycontent_url".localized()
            cell.subtitle.text = displayContent.url
        case buttonsIdx:
            collapsedCellPaths.addObjectIfNew(buttonsIdx)
        case footerIdx:
           collapsedCellPaths.addObjectIfNew(footerIdx)
        case actionsIdx:
            collapsedCellPaths.addObjectIfNew(actionsIdx)
        case durationIdx:
            collapsedCellPaths.addObjectIfNew(durationIdx)
        case borderRadiusIdx:
            cell.title.text = "ua_displaycontent_borderradius".localized()
            cell.subtitle.text = "\(displayContent.borderRadiusPoints)"
        case backgroundColorIdx:
            cell.title.text = "ua_displaycontent_backgroundcolor".localized()
            cell.subtitle.text = descriptionForColor(displayContent.backgroundColor)
        case dismissButtonIdx:
            cell.title.text = "ua_displaycontent_dismissbuttoncolor".localized()
            cell.subtitle.text = descriptionForColor(displayContent.dismissButtonColor)
        case allowFullscreenIdx:
            cell.title.text = "ua_displaycontent_allowfullscreendisplay".localized()
            cell.subtitle.text = (displayContent.allowFullScreenDisplay) ? "ua_yesno_yes".localized() : "ua_yesno_no".localized()
        default:
            break
        }

        return cell
    }


    func createScheduleCell(_ indexPath:IndexPath) -> UITableViewCell {
        // Handle button cell separately
        if indexPath == cancelScheduleIdx {
            let cell = tableView.dequeueReusableCell(withIdentifier: "AutomationDetailButtonCell", for: indexPath) as! AutomationDetailButtonCell

            cell.title.text = "ua_cancel_schedule".localized()
            cell.title.textColor = ThemeManager.shared.currentTheme.PrimaryText
            cell.backgroundColor = ThemeManager.shared.currentTheme.ButtonBackground

            return cell
        }

        guard let schedule = schedule else { return UITableViewCell() }

        let scheduleInfo = schedule.info as! UAInAppMessageScheduleInfo

        let cell = defaultAutomationDetailCell(indexPath)

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]

        switch indexPath {
        case identifierIdx:
            cell.title.text = "ua_scheduleinfo_identifier".localized()
            cell.subtitle.text = schedule.identifier
        case startIdx:
            cell.title.text = "ua_scheduleinfo_start".localized()
            if let start = scheduleInfo.start {
                cell.subtitle.text = dateFormatter.string(from: start)
            }
        case endIdx:
            cell.title.text = "ua_scheduleinfo_end".localized()
            if let end = scheduleInfo.end {
                cell.subtitle.text = dateFormatter.string(from: end)
            }
        case priorityIdx:
            cell.title.text = "ua_scheduleinfo_priority".localized()
            cell.subtitle.text = String(scheduleInfo.priority)
        case limitIdx:
            cell.title.text = "ua_scheduleinfo_limit".localized()
            cell.subtitle.text = String(scheduleInfo.limit)
        case triggersIdx:
            cell.title.text = "ua_scheduleinfo_triggers".localized()
            cell.accessoryType = .disclosureIndicator
            cell.subtitle.text = String(scheduleInfo.triggers.count)
        case delayIdx:
            cell.title.text = "ua_scheduleinfo_delay".localized()
            cell.accessoryType = .disclosureIndicator
            if let delay = scheduleInfo.delay {
                cell.subtitle.text = String(delay.seconds)
            } else {
                collapsedCellPaths.addObjectIfNew(delayIdx)
            }
        case editGracePeriodIdx:
            cell.title.text = "ua_scheduleinfo_editgraceperiod".localized()
            cell.subtitle.text = "\(scheduleInfo.editGracePeriod.descriptionWithUnits)"
        case intervalIdx:
            cell.title.text = "ua_scheduleinfo_interval".localized()
            cell.subtitle.text = "\(scheduleInfo.interval.descriptionWithUnits)"
        case isValidIdx:
            cell.title.text = "ua_scheduleinfo_isvalid".localized()
            cell.subtitle.text = (scheduleInfo.isValid) ? "ua_yesno_yes".localized() : "ua_yesno_no".localized()
        default:
            break
        }

        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if collapsedCellPaths.contains(indexPath) {
            return 0
        }

        return 44
    }

    func createMessageCell(_ indexPath:IndexPath) -> UITableViewCell {
        guard let schedule = schedule else {
            return UITableViewCell()
        }

        let scheduleInfo = schedule.info as! UAInAppMessageScheduleInfo

        let cell = defaultAutomationDetailCell(indexPath)

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]

        switch indexPath {
        case messageIdentifierIdx:
            cell.title.text = "ua_message_identifier".localized()
            cell.subtitle.text = scheduleInfo.message.identifier
        case nameIdx:
            cell.title.text = "ua_message_name".localized()
            if let name = scheduleInfo.message.name {
                cell.subtitle.text = name
            } else {
                collapsedCellPaths.addObjectIfNew(nameIdx)
            }
        case displayTypeIdx:
            cell.title.text = "ua_message_displaytype".localized()
            cell.subtitle.text = generateDisplayTypeSubtitle(scheduleInfo.message.displayType)
        case audienceIdx:
            cell.title.text = "ua_message_audience".localized()
            cell.subtitle.text = ""
            cell.accessoryType = .disclosureIndicator
            if scheduleInfo.message.audience == nil {
                collapsedCellPaths.addObjectIfNew(audienceIdx)
            }
        case extrasIdx:
            cell.title.text = "ua_message_extras".localized()
            cell.subtitle.text = ""
            cell.accessoryType = .disclosureIndicator
            if scheduleInfo.message.extras == nil {
                collapsedCellPaths.addObjectIfNew(extrasIdx)
            }
        default:
            break
        }

        return cell
    }

    private func generateDisplayTypeSubtitle(_ type:UAInAppMessageDisplayType) -> String {
        switch (type) {
        case .banner:
            return "ua_message_displaytype_banner".localized()
        case .fullScreen:
            return "ua_message_displaytype_fullscreen".localized()
        case .modal:
            return "ua_message_displaytype_modal".localized()
        case .HTML:
            return "ua_message_displaytype_html".localized()
        case .custom:
            return "ua_message_displaytype_custom".localized()
        default:
            return ""
        }
    }

    private func generatedMediaSubtitle(_ mediaInfo: UAInAppMessageMediaInfo?) -> String? {
        var subtitle:String?
        if let mediaInfo = mediaInfo {
            switch mediaInfo.type {
            case .image:
                subtitle = "ua_mediainfo_type_image".localized()
            case .video:
                subtitle = "ua_mediainfo_type_video".localized()
            case .youTube:
                subtitle = "ua_mediainfo_type_youTube".localized()
            @unknown default:
                subtitle = "ua_mediainfo_type_unknown".localized()
            }
            subtitle = subtitle! + ": \(mediaInfo.contentDescription)"
        }

        return subtitle
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case scheduleSection:
            return "ua_schedule_title".localized()
        case messageSection:
            return "ua_message_title".localized()
        case contentSection:
            if let scheduleInfo = self.schedule?.info as? UAInAppMessageScheduleInfo {
                switch (scheduleInfo.message.displayType) {
                case .banner:
                    return "ua_displaycontent_title_banner".localized()
                case .fullScreen:
                    return "ua_displaycontent_title_fullScreen".localized()
                case .modal:
                    return "ua_displaycontent_title_modal".localized()
                case .HTML:
                    return "ua_displaycontent_title_HTML".localized()
                case .custom:
                    return "ua_displaycontent_title_custom".localized()
                @unknown default:
                    return "ua_displaycontent_title_unknown".localized()
                }
            } else {
                return "ua_displaycontent_title_unknown".localized()
            }
        default:
            return "ua_displaycontent_title_unknown".localized()
        }
    }

    private func descriptionForMedia(_ mediaInfo: UAInAppMessageMediaInfo?) -> String? {
        var mediaDescription : String?
        if let mediaInfo = mediaInfo {
            switch mediaInfo.type {
            case .image:
                mediaDescription = "ua_mediainfo_type_image".localized()
            case .video:
                mediaDescription = "ua_mediainfo_type_video".localized()
            case .youTube:
                mediaDescription = "ua_mediainfo_type_youTube".localized()
            @unknown default:
                mediaDescription = "ua_mediainfo_type_unknown".localized()
            }
            mediaDescription = mediaDescription! + ": \(mediaInfo.contentDescription)"
        }
        return mediaDescription
    }

    private func descriptionForButtons(_ buttons : [UAInAppMessageButtonInfo]?, _ buttonLayout: UAInAppMessageButtonLayoutType) -> String? {
        var buttonsDescription : String?
        if let buttons = buttons {
            if (buttons.count > 0) {
                buttonsDescription = "\(buttons.count)"
                switch (buttonLayout) {
                case .stacked:
                    buttonsDescription = buttonsDescription! + String(format:": %@","ua_displaycontent_buttonLayout_stacked".localized())
                case .separate:
                    buttonsDescription = buttonsDescription! + String(format:": %@","ua_displaycontent_buttonLayout_separate".localized())
                case .joined:
                    buttonsDescription = buttonsDescription! + String(format:": %@","ua_displaycontent_buttonLayout_joined".localized())
                @unknown default:
                    buttonsDescription = buttonsDescription! + String(format:": %@","ua_displaycontent_buttonLayout_unknown".localized())
                }
            }
        }
        return buttonsDescription
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        super.prepare(for: segue, sender: sender)

        guard let selectedIdx = sender as? IndexPath else {
            fatalError("Unexpected sender: \(sender ?? "unknown sender")")
        }

        let scheduleInfo = schedule?.info as! UAInAppMessageScheduleInfo
        let message = scheduleInfo.message

        var heading : UAInAppMessageTextInfo?
        var body : UAInAppMessageTextInfo?
        var mediaInfo : UAInAppMessageMediaInfo?
        var buttons : [ UAInAppMessageButtonInfo ]?

        switch (message.displayType) {
        case .banner:
            let displayContent = message.displayContent as! UAInAppMessageBannerDisplayContent
            heading = displayContent.heading
            body = displayContent.body
            mediaInfo = displayContent.media
            buttons = displayContent.buttons
        case .fullScreen:
            let displayContent = message.displayContent as! UAInAppMessageFullScreenDisplayContent
            heading = displayContent.heading
            body = displayContent.body
            mediaInfo = displayContent.media
            buttons = displayContent.buttons
        case .modal:
            let displayContent = message.displayContent as! UAInAppMessageModalDisplayContent
            heading = displayContent.heading
            body = displayContent.body
            mediaInfo = displayContent.media
            buttons = displayContent.buttons
        case .HTML:
            let _ = message.displayContent as! UAInAppMessageHTMLDisplayContent
        // TODO - Implement HTML detail view
        case .custom:
            let _ = message.displayContent as! UAInAppMessageCustomDisplayContent
            // TODO - Implement custom detail view
        @unknown default:
            break
        }

        switch(segue.identifier ?? "") {
        case "ShowScheduleDelayDetail":
            // TODO - implement schedule delay detail view
            print("UNIMPLEMENTED")
        case TextInfoDetailViewController.segueID:
            guard let textInfoDetailViewController = segue.destination as? TextInfoDetailViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }

            switch (selectedIdx) {
            case headingIdx:
                textInfoDetailViewController.textInfo = heading
                textInfoDetailViewController.title = "ua_textinfo_title_heading".localized()
            case bodyIdx:
                textInfoDetailViewController.textInfo = body
                textInfoDetailViewController.title = "ua_textinfo_title_body".localized()
            default:
                print("ERROR: unexpected text info cell selected")
            }
        case MediaInfoDetailViewController.segueID:
            guard let mediaInfoDetailViewController = segue.destination as? MediaInfoDetailViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }

            switch (selectedIdx) {
            case mediaIdx:
                mediaInfoDetailViewController.mediaInfo = mediaInfo
            default:
                print("ERROR: unexpected media info cell selected")
            }
        case ButtonsTableViewController.segueID:
            guard let buttonsTableViewController = segue.destination as? ButtonsTableViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }

            switch (selectedIdx) {
            case buttonsIdx:
                buttonsTableViewController.buttons = buttons
            default:
                print("ERROR: unexpected buttons cell selected")
            }
        case TriggerTableViewController.segueID:
            guard let triggersTableViewController = segue.destination as? TriggerTableViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }

            switch (selectedIdx) {
            case triggersIdx:
                triggersTableViewController.triggers = scheduleInfo.triggers
            default:
                print("ERROR: unexpected triggers cell selected")
            }
        case AudienceDetailViewController.segueID:
            guard let audienceDetailViewController = segue.destination as? AudienceDetailViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }

            switch (selectedIdx) {
            case audienceIdx:
                audienceDetailViewController.audience = message.audience
            default:
                print("ERROR: unexpected audience info cell selected")
            }
        case ExtrasDetailViewController.segueID:
        guard let extrasDetailViewController = segue.destination as? ExtrasDetailViewController else {
            fatalError("Unexpected destination: \(segue.destination)")
        }

        switch (selectedIdx) {
        case extrasIdx:
            extrasDetailViewController.message = message
        default:
            print("ERROR: unexpected extras info cell selected")
        }
        default:
            print("ERROR: Unexpected Segue Identifier; \(segue.identifier ?? "unknown identifier")")
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
