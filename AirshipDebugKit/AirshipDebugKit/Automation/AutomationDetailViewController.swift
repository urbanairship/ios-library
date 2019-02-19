/* Copyright 2010-2019 Urban Airship and Contributors */

import UIKit
import AirshipKit

/**
 * The AutomationDetailViewController displays the details of a single
 * IAA schedule.
 */
class AutomationDetailViewController: UAStaticTableViewController {
    public static let segueID = "ShowAutomationDetail"

    /* The UASchedule to be displayed */
    public var schedule : UASchedule?
    
    // Schedule Cells
    @IBOutlet var scheduleIDCell: UITableViewCell!
    @IBOutlet weak var scheduleIDLabel: UILabel!
    @IBOutlet var schedulePriorityCell: UITableViewCell!
    @IBOutlet var schedulePriorityLabel: UILabel!
    @IBOutlet var scheduleTriggersCell: UITableViewCell!
    @IBOutlet var scheduleTriggersLabel: UILabel!
    @IBOutlet var scheduleLimitLabel: UILabel!
    @IBOutlet var scheduleStartCell: UITableViewCell!
    @IBOutlet var scheduleStartLabel: UILabel!
    @IBOutlet var scheduleEndCell: UITableViewCell!
    @IBOutlet var scheduleEndLabel: UILabel!
    @IBOutlet var scheduleDelayCell: UITableViewCell!
    @IBOutlet var scheduleDelayLabel: UILabel!
    @IBOutlet var scheduleEditGracePeriodLabel: UILabel!
    @IBOutlet var scheduleIntervalLabel: UILabel!
    @IBOutlet var scheduleIsValid: UILabel!
    @IBOutlet var cancelScheduleCell: UITableViewCell!
    
    // Message Cells
    @IBOutlet var messageIDCell: UITableViewCell!
    @IBOutlet weak var messageIDLabel: UILabel!
    @IBOutlet weak var displayTypeLabel: UILabel!
    @IBOutlet var messageNameCell: UITableViewCell!
    @IBOutlet var messageNameLabel: UILabel!
    @IBOutlet var audienceCell: UITableViewCell!
    @IBOutlet var audienceLabel: UILabel!
    
    // Content Cells
    @IBOutlet var placementCell: UITableViewCell!
    @IBOutlet var placementLabel: UILabel!
    @IBOutlet var layoutCell: UITableViewCell!
    @IBOutlet var layoutLabel: UILabel!
    @IBOutlet var headingCell: UITableViewCell!
    @IBOutlet var headingLabel: UILabel!
    @IBOutlet var bodyCell: UITableViewCell!
    @IBOutlet var bodyLabel: UILabel!
    @IBOutlet var mediaCell: UITableViewCell!
    @IBOutlet var mediaLabel: UILabel!
    @IBOutlet var buttonsCell: UITableViewCell!
    @IBOutlet var buttonsLabel: UILabel!
    @IBOutlet var durationCell: UITableViewCell!
    @IBOutlet var durationLabel: UILabel!
    @IBOutlet var actionsCell: UITableViewCell!
    @IBOutlet var actionsLabel: UILabel!
    @IBOutlet var borderRadiusCell: UITableViewCell!
    @IBOutlet var borderRadiusLabel: UILabel!
    @IBOutlet var backgroundColorCell: UITableViewCell!
    @IBOutlet var backgroundColorLabel: UILabel!
    @IBOutlet var dismissButtonColorCell: UITableViewCell!
    @IBOutlet var dismissButtonColorLabel: UILabel!
    @IBOutlet var footerCell: UITableViewCell!
    @IBOutlet var footerLabel: UILabel!
    @IBOutlet var urlCell: UITableViewCell!
    @IBOutlet var urlLabel: UILabel!
    @IBOutlet var allowFullScreenDisplayCell: UITableViewCell!
    @IBOutlet var allowFullScreenDisplayLabel: UILabel!
    
    fileprivate enum SECTIONS {
        static let SCHEDULE = 0
        static let MESSAGE = 1
        static let DISPLAY_CONTENT = 2
    }
    
    private var message : UAInAppMessage?
    private let inAppMessageManager = UAirship.inAppMessageManager()

    override func viewWillAppear(_ animated: Bool) {
        refreshView()
    }
    
    func refreshView() {
        guard let schedule = schedule else { return }
        
        // Schedule cells
        scheduleIDLabel.text = schedule.identifier
        
        let scheduleInfo = schedule.info as! UAInAppMessageScheduleInfo
        schedulePriorityLabel.text = String(scheduleInfo.priority)
        scheduleTriggersLabel.text = String(scheduleInfo.triggers.count)
        scheduleLimitLabel.text = String(scheduleInfo.limit)
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        
        var scheduleStartDescription : String?
        if let start = scheduleInfo.start {
            scheduleStartDescription = dateFormatter.string(from: start)
        }
        updateOrHideCell(scheduleStartCell, label: scheduleStartLabel, newText: scheduleStartDescription)
        
        var scheduleEndDescription : String?
        if let end = scheduleInfo.end {
            scheduleEndDescription = dateFormatter.string(from: end)
        }
        updateOrHideCell(scheduleEndCell, label: scheduleEndLabel, newText: scheduleEndDescription)

        var scheduleDelayDescription : String?
        if let delay = scheduleInfo.delay {
            scheduleDelayDescription = String(delay.seconds)
        }
        updateOrHideCell(scheduleDelayCell, label: scheduleDelayLabel, newText: scheduleDelayDescription)

        scheduleEditGracePeriodLabel.text = "\(scheduleInfo.editGracePeriod.descriptionWithUnits)"

        scheduleIntervalLabel.text = "\(scheduleInfo.interval.descriptionWithUnits)"

        scheduleIsValid.text = (scheduleInfo.isValid) ? "ua_yesno_yes".localized() : "ua_yesno_no".localized()
        
        // Message Cells
        self.message = scheduleInfo.message
        guard let message = self.message else { return }
        
        messageIDLabel.text = message.identifier
        
        let messageName = message.name
        updateOrHideCell(messageNameCell, label: messageNameLabel, newText: messageName)
        
        switch (message.displayType) {
        case .banner:
            displayTypeLabel?.text = "ua_message_displaytype_banner".localized()
        case .fullScreen:
            displayTypeLabel?.text = "ua_message_displaytype_fullscreen".localized()
        case .modal:
            displayTypeLabel?.text = "ua_message_displaytype_modal".localized()
        case .HTML:
            displayTypeLabel?.text = "ua_message_displaytype_html".localized()
        case .custom:
            displayTypeLabel?.text = "ua_message_displaytype_custom".localized()
        }
        
        if (message.audience == nil) {
            hideCell(audienceCell)
        } else {
            showCell(audienceCell)
        }
        
        // TODO - add extras detail view
        // TODO - add actions detail view

        // Content Cells
        var placementDescription : String?
        var layoutDescription : String?
        var headingDescription : String?
        var bodyDescription : String?
        var mediaDescription : String?
        var footerDescription : String?
        var buttonsDescription : String?
        var durationDescription : String?
        var actionsDescription : String?
        var borderRadiusDescription : String?
        var backgroundColorDescription : String?
        var dismissButtonColorDescription : String?
        var urlDescription : String?
        var allowFullScreenDisplayDescription : String?
        
        switch (message.displayType) {
        case .banner:
            let displayContent = message.displayContent as! UAInAppMessageBannerDisplayContent
            
            switch displayContent.placement {
            case .top:
                placementDescription = "ua_displaycontent_placement_top".localized()
            case .bottom:
                placementDescription = "ua_displaycontent_placement_bottom".localized()
            }
            
            switch displayContent.contentLayout {
            case .mediaLeft:
                layoutDescription = "ua_displaycontent_contentLayout_mediaLeft".localized()
            case .mediaRight:
                layoutDescription = "ua_displaycontent_contentLayout_mediaRight".localized()
            }
            
            headingDescription = displayContent.heading?.text
            bodyDescription = displayContent.body?.text

            mediaDescription = descriptionForMedia(displayContent.media)

            buttonsDescription = descriptionForButtons(displayContent.buttons, displayContent.buttonLayout)
            
            actionsDescription = (displayContent.actions != nil) ? "ua_yesno_yes".localized() : "ua_yesno_no".localized()
            
            durationDescription = String(format: "ua_displaycontent_duration_format".localized(), displayContent.durationSeconds)
            
            borderRadiusDescription = "\(displayContent.borderRadiusPoints)"
            
            backgroundColorDescription = descriptionForColor(displayContent.backgroundColor)
            dismissButtonColorDescription = descriptionForColor(displayContent.dismissButtonColor)

        case .fullScreen:
            let displayContent = message.displayContent as! UAInAppMessageFullScreenDisplayContent
            
            switch displayContent.contentLayout {
            case .headerMediaBody:
                layoutDescription = "ua_displaycontent_contentLayout_headerMediaBody".localized()
            case .mediaHeaderBody:
                layoutDescription = "ua_displaycontent_contentLayout_mediaHeaderBody".localized()
            case .headerBodyMedia:
                layoutDescription = "ua_displaycontent_contentLayout_headerBodyMedia".localized()
            }
            
            headingDescription = displayContent.heading?.text
            bodyDescription = displayContent.body?.text
            
            mediaDescription = descriptionForMedia(displayContent.media)

            buttonsDescription = descriptionForButtons(displayContent.buttons, displayContent.buttonLayout)
            
            footerDescription = displayContent.footer?.label.text

            backgroundColorDescription = descriptionForColor(displayContent.backgroundColor)
            dismissButtonColorDescription = descriptionForColor(displayContent.dismissButtonColor)

        case .modal:
            let displayContent = message.displayContent as! UAInAppMessageModalDisplayContent

            switch displayContent.contentLayout {
            case .headerMediaBody:
                layoutDescription = "ua_displaycontent_contentLayout_headerMediaBody".localized()
            case .mediaHeaderBody:
                layoutDescription = "ua_displaycontent_contentLayout_mediaHeaderBody".localized()
            case .headerBodyMedia:
                layoutDescription = "ua_displaycontent_contentLayout_headerBodyMedia".localized()
            }
            
            headingDescription = displayContent.heading?.text
            bodyDescription = displayContent.body?.text
            
            mediaDescription = descriptionForMedia(displayContent.media)
            
            buttonsDescription = descriptionForButtons(displayContent.buttons, displayContent.buttonLayout)

            footerDescription = displayContent.footer?.label.text
            
            backgroundColorDescription = descriptionForColor(displayContent.backgroundColor)
            dismissButtonColorDescription = descriptionForColor(displayContent.dismissButtonColor)
            borderRadiusDescription = "\(displayContent.borderRadiusPoints)"
            
            allowFullScreenDisplayDescription = (displayContent.allowFullScreenDisplay) ? "ua_yesno_yes".localized() : "ua_yesno_no".localized()

        case .HTML:
            let displayContent = message.displayContent as! UAInAppMessageHTMLDisplayContent
            
            urlDescription = displayContent.url
            backgroundColorDescription = descriptionForColor(displayContent.backgroundColor)
            dismissButtonColorDescription = descriptionForColor(displayContent.dismissButtonColor)
            borderRadiusDescription = "\(displayContent.borderRadiusPoints)"
            allowFullScreenDisplayDescription = (displayContent.allowFullScreenDisplay) ? "ua_yesno_yes".localized() : "ua_yesno_no".localized()
            // TODO - should we fetch the html from the url and display it? Maybe in an accessory view?
            
        case .custom:  // TODO - IMPLEMENT
            let _ = message.displayContent as! UAInAppMessageCustomDisplayContent
        }
        
        updateOrHideCell(placementCell, label: placementLabel, newText: placementDescription)
        updateOrHideCell(layoutCell, label: layoutLabel, newText: layoutDescription)
        updateOrHideCell(headingCell, label: headingLabel, newText: headingDescription)
        updateOrHideCell(bodyCell, label: bodyLabel, newText: bodyDescription)
        updateOrHideCell(mediaCell, label: mediaLabel, newText: mediaDescription)
        updateOrHideCell(buttonsCell, label: buttonsLabel, newText: buttonsDescription)
        updateOrHideCell(durationCell, label: durationLabel, newText: durationDescription)
        updateOrHideCell(actionsCell, label: actionsLabel, newText: actionsDescription)
        updateOrHideCell(borderRadiusCell, label: borderRadiusLabel, newText: borderRadiusDescription)
        updateOrHideCell(backgroundColorCell, label: backgroundColorLabel, newText: backgroundColorDescription)
        updateOrHideCell(dismissButtonColorCell, label: dismissButtonColorLabel, newText: dismissButtonColorDescription)
        updateOrHideCell(footerCell, label: footerLabel, newText: footerDescription)
        updateOrHideCell(urlCell, label: urlLabel, newText: urlDescription)
        updateOrHideCell(allowFullScreenDisplayCell, label: allowFullScreenDisplayLabel, newText: allowFullScreenDisplayDescription)
        
        // TODO - add button to display message
        
        tableView.reloadData()
    }
    
    fileprivate func descriptionForMedia(_ mediaInfo: UAInAppMessageMediaInfo?) -> String? {
        var mediaDescription : String?
        if let mediaInfo = mediaInfo {
            switch mediaInfo.type {
            case .image:
                mediaDescription = "ua_mediainfo_type_image".localized()
            case .video:
                mediaDescription = "ua_mediainfo_type_video".localized()
            case .youTube:
                mediaDescription = "ua_mediainfo_type_youTube".localized()
            }
            mediaDescription = mediaDescription! + ": \(mediaInfo.contentDescription)"
        }
        return mediaDescription
    }
    
    fileprivate func descriptionForButtons(_ buttons : [UAInAppMessageButtonInfo]?, _ buttonLayout: UAInAppMessageButtonLayoutType) -> String? {
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
                }
            }
        }
        return buttonsDescription
    }
    
    // MARK: - UITableViewDataSource
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // let superview override
        let heightFromSuperview = super.tableView(tableView, heightForRowAt: indexPath)
        if heightFromSuperview != UITableView.automaticDimension {
            return heightFromSuperview
        }
        
        // superview didn't override, so let's check our cells
        let cell = super.tableView(tableView, cellForRowAt: indexPath)        
        if cell == headingCell {
            return heightForCell(cell, resizingLabel:headingLabel)
        } else if cell == bodyCell {
            return heightForCell(cell, resizingLabel:bodyLabel)
        } else if cell == mediaCell {
            return heightForCell(cell, resizingLabel:mediaLabel)
        } else if cell == urlCell {
            return heightForCell(cell, resizingLabel:urlLabel)
        } else {
            return UITableView.automaticDimension
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case SECTIONS.SCHEDULE:
            return "ua_schedule_title".localized()
        case SECTIONS.MESSAGE:
            return "ua_message_title".localized()
        case SECTIONS.DISPLAY_CONTENT:
            if let message = self.message {
                switch (message.displayType) {
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
                }
            } else {
                return "ua_displaycontent_title_unknown".localized()
            }
        default:
            return nil
        }
    }
    
    // MARK: - UITableViewDelegate
    override func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return action == #selector(copy(_:))
    }
    
    override func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
        if action == #selector(copy(_:)) {
            var copiedText : String?
            switch tableView.cellForRow(at: indexPath) {
            case scheduleIDCell:
                copiedText = scheduleIDLabel.text
            case messageIDCell:
                copiedText = messageIDLabel.text
            default:
                break
            }
            if let copiedText = copiedText {
                let pasteboard = UIPasteboard.general
                pasteboard.string = copiedText
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch tableView.cellForRow(at: indexPath) {
        case cancelScheduleCell:
            // cancel the schedule
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
        default:
            break
        }
        
        tableView.deselectRow(at: indexPath, animated: true)        
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        super.prepare(for: segue, sender: sender)
        
        guard let selectedCell = sender as? UITableViewCell else {
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
        }

        switch(segue.identifier ?? "") {
        case "ShowScheduleDelayDetail":
            // TODO - implement schedule delay detail view
            print("UNIMPLEMENTED")
        case TextInfoDetailViewController.segueID:
            guard let textInfoDetailViewController = segue.destination as? TextInfoDetailViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }
            
            switch (selectedCell) {
            case headingCell:
                textInfoDetailViewController.textInfo = heading
                textInfoDetailViewController.title = "ua_textinfo_title_heading".localized()
            case bodyCell:
                textInfoDetailViewController.textInfo = body
                textInfoDetailViewController.title = "ua_textinfo_title_body".localized()
            default:
                print("ERROR: unexpected text info cell selected")
            }
        case MediaInfoDetailViewController.segueID:
            guard let mediaInfoDetailViewController = segue.destination as? MediaInfoDetailViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }
            
            switch (selectedCell) {
            case mediaCell:
                mediaInfoDetailViewController.mediaInfo = mediaInfo
            default:
                print("ERROR: unexpected media info cell selected")
            }
        case ButtonsTableViewController.segueID:
            guard let buttonsTableViewController = segue.destination as? ButtonsTableViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }

            switch (selectedCell) {
            case buttonsCell:
                buttonsTableViewController.buttons = buttons
            default:
                print("ERROR: unexpected buttons cell selected")
            }
        case TriggerTableViewController.segueID:
            guard let triggersTableViewController = segue.destination as? TriggerTableViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }
            
            switch (selectedCell) {
            case scheduleTriggersCell:
                triggersTableViewController.triggers = scheduleInfo.triggers
            default:
                print("ERROR: unexpected triggers cell selected")
            }
        case AudienceDetailViewController.segueID:
            guard let audienceDetailViewController = segue.destination as? AudienceDetailViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }
            
            switch (selectedCell) {
            case audienceCell:
                audienceDetailViewController.audience = message.audience
            default:
                print("ERROR: unexpected audience info cell selected")
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

