/* Copyright Airship and Contributors */

import UIKit

#if canImport(AirshipCore)
import AirshipCore
import AirshipAutomation
#elseif canImport(AirshipKit)
import AirshipKit
#endif


/**
 * The ButtonDetailViewController displays the details of an IAA
 * message buttons. It is used to display the details of buttons and
 * footers.
 */
class ButtonDetailViewController: StaticTableViewController {
    public static let segueID = "ButtonDetailSegue"
    
    /* The UAInAppMessageButtonInfo to be displayed. */
    public var button : InAppMessageButtonInfo?

    @IBOutlet private weak var buttonIDCell: UITableViewCell!
    @IBOutlet private weak var buttonIDTitle: UILabel!
    @IBOutlet private weak var buttonIDLabel: UILabel!

    @IBOutlet private weak var buttonLabelCell: UITableViewCell!
    @IBOutlet private weak var buttonLabelTitle: UILabel!
    @IBOutlet private weak var buttonLabelLabel: UILabel!

    @IBOutlet private weak var buttonDismissBehaviorCell: UITableViewCell!
    @IBOutlet private weak var buttonDismissBehaviorTitle: UILabel!
    @IBOutlet private weak var buttonDismissBehaviorLabel: UILabel!

    @IBOutlet private weak var borderRadiusCell: UITableViewCell!
    @IBOutlet private weak var borderRadiusTitle: UILabel!
    @IBOutlet private weak var borderRadiusLabel: UILabel!

    @IBOutlet private weak var backgroundColorCell: UITableViewCell!
    @IBOutlet private weak var backgroundColorTitle: UILabel!
    @IBOutlet private weak var backgroundColorLabel: UILabel!

    @IBOutlet private weak var borderColorCell: UITableViewCell!
    @IBOutlet private weak var borderColorTitle: UILabel!
    @IBOutlet private weak var borderColorLabel: UILabel!

    func setCellTheme() {
        buttonIDCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        buttonIDTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        buttonIDLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText

        buttonLabelCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        buttonLabelTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        buttonLabelLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText

        buttonDismissBehaviorCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        buttonDismissBehaviorTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        buttonDismissBehaviorLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText

        borderRadiusCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        borderRadiusTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        borderRadiusLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText

        backgroundColorCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        backgroundColorTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        backgroundColorLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText

        borderColorCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        borderColorTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        borderColorLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setCellTheme()
        refreshView()
    }
    
    func refreshView() {
        guard let button = button else { return }
        
        buttonIDLabel.text = button.identifier
        buttonLabelLabel.text = button.label.text
        switch button.behavior {
        case .dismiss:
            buttonDismissBehaviorLabel.text = "ua_button_behavior_dismiss".localized()
        case .cancel:
            buttonDismissBehaviorLabel.text = "ua_button_behavior_cancel".localized()
        @unknown default:
            buttonDismissBehaviorLabel.text = "ua_button_behavior_unknown".localized()
        }
        borderRadiusLabel.text = "\(button.borderRadiusPoints)"
        backgroundColorLabel.text = descriptionForColor(button.backgroundColor)
        borderColorLabel.text = descriptionForColor(button.borderColor)
        // TODO - add actions - nullable
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        super.prepare(for: segue, sender: sender)
        
        guard let selectedCell = sender as? UITableViewCell else {
            fatalError("Unexpected sender: \(sender ?? "unknown sender")")
        }
        
        switch(segue.identifier ?? "") {
        case TextInfoDetailViewController.segueID:
            guard let textInfoDetailViewController = segue.destination as? TextInfoDetailViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }
            
            switch (selectedCell) {
            case buttonLabelCell:
                textInfoDetailViewController.textInfo = button?.label
                textInfoDetailViewController.title = "ua_textinfo_title_button".localized()
            default:
                print("ERROR: unexpected text info cell selected")
            }
        default:
            print("ERROR: Unexpected Segue Identifier; \(segue.identifier ?? "unknown identifier")")
        }
    }
}
