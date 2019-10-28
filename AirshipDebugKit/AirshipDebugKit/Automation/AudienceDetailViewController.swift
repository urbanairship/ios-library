/* Copyright Airship and Contributors */

import UIKit
import AirshipKit

/**
 * The AudienceDetailViewController displays the details of an IAA
 * audience.
 */
class AudienceDetailViewController: UAStaticTableViewController {
    public static let segueID = "AudienceSegue"

    /* The UAInAppMessageAudience to be displayed. */
    public var audience : UAInAppMessageAudience?

    @IBOutlet private weak var notificationsOptInCell: UITableViewCell!
    @IBOutlet private weak var notificationsOptInTitle: UILabel!
    @IBOutlet private weak var notificationsOptInLabel: UILabel!

    @IBOutlet private weak var locationOptInCell: UITableViewCell!
    @IBOutlet private weak var locationOptInTitle: UILabel!
    @IBOutlet private weak var locationOptInLabel: UILabel!

    @IBOutlet private weak var languageIDsCell: UITableViewCell!
    @IBOutlet private weak var languageIDsTitle: UILabel!
    @IBOutlet private weak var languageIDsLabel: UILabel!

    @IBOutlet private weak var tagSelectorCell: UITableViewCell!
    @IBOutlet private weak var tagSelectorTitle: UILabel!
    @IBOutlet private weak var tagSelectorLabel: UILabel!

    @IBOutlet private weak var versionPredicateTitle: UILabel!
    @IBOutlet private weak var versionPredicateCell: UITableViewCell!
    @IBOutlet private weak var versionPredicateLabel: UILabel!

    @IBOutlet private weak var missBehaviorTitle: UILabel!
    @IBOutlet private weak var missBehaviorLabel: UILabel!
    @IBOutlet private weak var missBehaviorCell: UITableViewCell!

    @IBOutlet private weak var inAudienceTitle: UILabel!
    @IBOutlet private weak var inAudienceCell: UITableViewCell!
    @IBOutlet private weak var inAudienceLabel: UILabel!

    @IBOutlet private weak var checkAudienceTitle: UILabel!
    @IBOutlet private weak var checkAudienceCell: UITableViewCell!
    
    private let inAppMessageManager = UAInAppMessageManager.shared()
    private var inAudience : Bool?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setCellTheme()
        refreshView()
    }

    func setCellTheme() {
        notificationsOptInCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        notificationsOptInTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        notificationsOptInLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText

        locationOptInCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        locationOptInTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        locationOptInLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText

        locationOptInCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        locationOptInTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        locationOptInLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText

        languageIDsCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        languageIDsTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        languageIDsLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText

        tagSelectorCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        tagSelectorTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        tagSelectorLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText

        versionPredicateCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        versionPredicateTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        versionPredicateLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText

        missBehaviorCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        missBehaviorTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        missBehaviorLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText

        inAudienceCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        inAudienceTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        inAudienceLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText

        checkAudienceCell.backgroundColor = ThemeManager.shared.currentTheme.ButtonBackground
        checkAudienceTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
    }

    func refreshView() {
        guard let audience = audience else { return }
        
        // notification opt-in
        var notificationsOptInDescription : String?
        if let notificationsOptIn = audience.notificationsOptIn {
            notificationsOptInDescription = notificationsOptIn.stringValue
        }
        updateOrHideCell(notificationsOptInCell, label: notificationsOptInLabel, newText: notificationsOptInDescription)
        
        // locationOptIn
        var locationOptInDescription : String?
        if let locationOptIn = audience.locationOptIn {
            locationOptInDescription = locationOptIn.stringValue
        }
        updateOrHideCell(locationOptInCell, label: locationOptInLabel, newText: locationOptInDescription)
        
        // languageIDs
        var languageIDsDescription : String?
        if let languageIDs = audience.languageIDs {
            if (languageIDs.count > 0) {
                languageIDsDescription = "\(languageIDs.count)"
            }
        }
        updateOrHideCell(languageIDsCell, label: languageIDsLabel, newText: languageIDsDescription)
        // TODO - add language IDs table view
        
        // tagSelector
        var tagSelectorDescription : String?
        if audience.tagSelector != nil {
            tagSelectorDescription = audience.tagSelector!.debugDescription
        }
        updateOrHideCell(tagSelectorCell, label: tagSelectorLabel, newText: tagSelectorDescription)

        // versionPredicate
        var versionPredicateDescription : String?
        if let versionPredicate = audience.versionPredicate {
            versionPredicateDescription = versionPredicate.payload.description
        }
        updateOrHideCell(versionPredicateCell, label: versionPredicateLabel, newText: versionPredicateDescription)

        // missbehavior
        switch (audience.missBehavior) {
        case .cancel:
            missBehaviorLabel.text = "ua_audience_missBehavior_cancel".localized()
        case .skip:
            missBehaviorLabel.text = "ua_audience_missBehavior_skip".localized()
        case .penalize:
            missBehaviorLabel.text = "ua_audience_missBehavior_penalize".localized()
        @unknown default:
            missBehaviorLabel.text = "ua_audience_missBehavior_unknown".localized()
        }
        
        // is the user a member of the audience?
        var inAudienceDescription : String?
        if let inAudience = inAudience {
            inAudienceDescription = (inAudience) ? "ua_yesno_yes".localized() : "ua_yesno_no".localized()
        }
        updateOrHideCell(inAudienceCell, label: inAudienceLabel, newText: inAudienceDescription)
        
        self.tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // let superview override
        let heightFromSuperview = super.tableView(tableView, heightForRowAt: indexPath)
        if heightFromSuperview != UITableView.automaticDimension {
            return heightFromSuperview
        }
        
        // superview didn't override, so let's check our cells for ones that need to change height
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        if cell == versionPredicateCell {
            return heightForCell(cell, resizingLabel:versionPredicateLabel)
        } else {
            return UITableView.automaticDimension
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch tableView.cellForRow(at: indexPath) {
        case checkAudienceCell:
            // check the audience
            guard let audience = audience else {
                tableView.deselectRow(at: indexPath, animated: true)
                return
            }
            self.inAppMessageManager?.check(audience, completionHandler: { (inAudience, error) in
                DispatchQueue.main.async {
                    self.inAudience = inAudience && (error == nil)
                    tableView.deselectRow(at: indexPath, animated: true)
                    self.refreshView()
                }
            })
        default:
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
}
