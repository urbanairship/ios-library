/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
import AirshipAutomation
#elseif canImport(Airship)
import Airship
#endif

class InAppMessageDetailViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet var tableView: UITableView!
    
    public static let segueID = "InAppMessageDetailSegue"
    
    /* The UASchedule to be displayed */
    public var schedule : InAppMessageSchedule?
    
    var collapsedCellPaths:[IndexPath] = []
    
    /* Section
     * Note: Number of sections and sections for row are defined in their respective
     * table view data source methods
     */
    let messageSection = 0,
    contentSection = 1

    // Indexes section 0
    let nameIdx = IndexPath(row: 0, section: 0),
    displayTypeIdx = IndexPath(row: 1, section: 0),
    extrasIdx = IndexPath(row: 2, section: 0)

    // Indexes section 1
    let placementIdx = IndexPath(row: 0, section: 1),
    contentLayoutIdx = IndexPath(row: 1, section: 1),
    headingIdx = IndexPath(row: 2, section: 1),
    bodyIdx = IndexPath(row: 3, section: 1),
    mediaIdx = IndexPath(row: 4, section: 1),
    urlIdx = IndexPath(row: 5, section: 1),
    buttonsIdx = IndexPath(row: 6, section: 1),
    footerIdx = IndexPath(row: 7, section: 1),
    actionsIdx = IndexPath(row: 8, section: 1),
    durationIdx = IndexPath(row: 9, section: 1),
    borderRadiusIdx = IndexPath(row: 10, section: 1),
    backgroundColorIdx = IndexPath(row: 11, section: 1),
    dismissButtonIdx = IndexPath(row: 12, section: 1),
    allowFullscreenIdx = IndexPath(row: 13, section: 1)
    
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
        case messageSection:
            return 3
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

            copiedText = cell.subtitle.text

            if let copiedText = copiedText {
                let pasteboard = UIPasteboard.general
                pasteboard.string = copiedText
            }
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath {
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
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if collapsedCellPaths.contains(indexPath) {
            return 0
        }

        return 44
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case messageSection:
            return "ua_message_title".localized()
        case contentSection:
            switch (schedule?.message.displayType) {
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
            case .none: fallthrough
            @unknown default:
                return "ua_displaycontent_title_unknown".localized()
            }
        default:
            return "ua_displaycontent_title_unknown".localized()
        }
    }
        
    func createContentCell(_ indexPath:IndexPath) -> UITableViewCell {
        guard let schedule = schedule else { return UITableViewCell() }
        let message = schedule .message

        switch (message.displayType) {
        case .banner:
            let displayContent = message.displayContent as! InAppMessageBannerDisplayContent
            return createBannerContentCell(indexPath, displayContent: displayContent)
        case .fullScreen:
            let displayContent = message.displayContent as! InAppMessageFullScreenDisplayContent
            return createFullScreenContentCell(indexPath, displayContent: displayContent)
        case .modal:
            let displayContent = message.displayContent as! InAppMessageModalDisplayContent
            return createModalContentCell(indexPath, displayContent: displayContent)
        case .HTML:
            let displayContent = message.displayContent as! InAppMessageHTMLDisplayContent
            return createHTMLContentCell(indexPath, displayContent: displayContent)
        case .custom:  // TODO - IMPLEMENT
            let _ = message.displayContent as! InAppMessageCustomDisplayContent
        @unknown default:
            let cell = defaultInAppMessageDetailCell(indexPath)
            cell.title.text = "ua_displaycontent_unknown".localized()
            return cell
        }

        return UITableViewCell()
    }
    
    func defaultInAppMessageDetailCell(_ indexPath:IndexPath) -> AutomationDetailCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AutomationDetailCell", for: indexPath) as! AutomationDetailCell

        // Remove storyboard placeholders
        cell.title.text = nil
        cell.subtitle.text = nil

        cell.backgroundColor = ThemeManager.shared.currentTheme.Background
        cell.title.textColor = ThemeManager.shared.currentTheme.PrimaryText
        cell.subtitle.textColor = ThemeManager.shared.currentTheme.SecondaryText
        // hide accessory by default
        cell.accessoryType = .none

        return cell
    }
    
    func createMessageCell(_ indexPath:IndexPath) -> UITableViewCell {
        guard let schedule = schedule else {
            return UITableViewCell()
        }

        let message = schedule.message
        
        let cell = defaultInAppMessageDetailCell(indexPath)

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]

        switch indexPath {
        case nameIdx:
            cell.title.text = "ua_message_name".localized()
            if let name = message.name {
                cell.subtitle.text = name
            } else {
                collapsedCellPaths.addObjectIfNew(nameIdx)
            }
        case displayTypeIdx:
            cell.title.text = "ua_message_displaytype".localized()
            cell.subtitle.text = generateDisplayTypeSubtitle(message.displayType)
        case extrasIdx:
            cell.title.text = "ua_message_extras".localized()
            cell.subtitle.text = ""
            cell.accessoryType = .disclosureIndicator
            if message.extras == nil {
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

    private func generatedMediaSubtitle(_ mediaInfo: InAppMessageMediaInfo?) -> String? {
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
    
    func getDisplayContentTitle() -> String? {
        switch (schedule!.message.displayType) {
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
    }
    
    private func createBannerContentCell(_ indexPath:IndexPath, displayContent:InAppMessageBannerDisplayContent) -> UITableViewCell {
        let cell = defaultInAppMessageDetailCell(indexPath)

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

    private func createFullScreenContentCell(_ indexPath:IndexPath, displayContent:InAppMessageFullScreenDisplayContent) -> UITableViewCell {
        let cell = defaultInAppMessageDetailCell(indexPath)

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

    private func createModalContentCell(_ indexPath:IndexPath, displayContent:InAppMessageModalDisplayContent) -> UITableViewCell {
        let cell = defaultInAppMessageDetailCell(indexPath)

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

    private func createHTMLContentCell(_ indexPath:IndexPath, displayContent:InAppMessageHTMLDisplayContent) -> UITableViewCell {
        let cell = defaultInAppMessageDetailCell(indexPath)

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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        guard let selectedIdx = sender as? IndexPath else {
            fatalError("Unexpected sender: \(sender ?? "unknown sender")")
        }
        
        let message = schedule!.message

        var heading : InAppMessageTextInfo?
        var body : InAppMessageTextInfo?
        var mediaInfo : InAppMessageMediaInfo?
        var buttons : [ InAppMessageButtonInfo ]?

        switch (message.displayType) {
        case .banner:
            let displayContent = message.displayContent as! InAppMessageBannerDisplayContent
            heading = displayContent.heading
            body = displayContent.body
            mediaInfo = displayContent.media
            buttons = displayContent.buttons
        case .fullScreen:
            let displayContent = message.displayContent as! InAppMessageFullScreenDisplayContent
            heading = displayContent.heading
            body = displayContent.body
            mediaInfo = displayContent.media
            buttons = displayContent.buttons
        case .modal:
            let displayContent = message.displayContent as! InAppMessageModalDisplayContent
            heading = displayContent.heading
            body = displayContent.body
            mediaInfo = displayContent.media
            buttons = displayContent.buttons
        case .HTML:
            let _ = message.displayContent as! InAppMessageHTMLDisplayContent
        // TODO - Implement HTML detail view
        case .custom:
            let _ = message.displayContent as! InAppMessageCustomDisplayContent
            // TODO - Implement custom detail view
        @unknown default:
            break
        }
        
        switch(segue.identifier ?? "") {
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
    
    private func descriptionForMedia(_ mediaInfo: InAppMessageMediaInfo?) -> String? {
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

    private func descriptionForButtons(_ buttons : [InAppMessageButtonInfo]?, _ buttonLayout: UAInAppMessageButtonLayoutType) -> String? {
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
    
}
