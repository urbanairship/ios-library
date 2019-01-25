/* Copyright 2018 Urban Airship and Contributors */

import UIKit
import AirshipKit

/**
 * The AudienceDetailViewController displays the details of an IAA
 * audience.
 */
class AudienceDetailViewController: UAStaticTableViewController {
    public static let segueID = "ShowAudienceDetail"

    /* The UAInAppMessageAudience to be displayed. */
    public var audience : UAInAppMessageAudience?
    
    @IBOutlet var notificationsOptInCell: UITableViewCell!
    @IBOutlet var notificationsOptInLabel: UILabel!
    @IBOutlet var locationOptInCell: UITableViewCell!
    @IBOutlet var locationOptInLabel: UILabel!
    @IBOutlet var languageIDsCell: UITableViewCell!
    @IBOutlet var languageIDsLabel: UILabel!
    @IBOutlet var tagSelectorCell: UITableViewCell!
    @IBOutlet var tagSelectorLabel: UILabel!
    @IBOutlet var versionPredicateCell: UITableViewCell!
    @IBOutlet var versionPredicateLabel: UILabel!
    @IBOutlet var missBehaviorLabel: UILabel!
    @IBOutlet var inAudienceCell: UITableViewCell!
    @IBOutlet var inAudienceLabel: UILabel!
    @IBOutlet var checkAudienceCell: UITableViewCell!
    
    private let inAppMessageManager = UAirship.inAppMessageManager()
    private var inAudience : Bool?
    
    override func viewWillAppear(_ animated: Bool) {
        refreshView()
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
