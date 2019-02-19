/* Copyright 2010-2019 Urban Airship and Contributors */

import UIKit
import AirshipKit

/**
 * The ButtonDetailViewController displays the details of an IAA
 * message buttons. It is used to display the details of buttons and
 * footers.
 */
class ButtonDetailViewController: UAStaticTableViewController {
    public static let segueID = "ShowButtonDetail"
    
    /* The UAInAppMessageButtonInfo to be displayed. */
    public var button : UAInAppMessageButtonInfo?
    
    @IBOutlet var buttonIDLabel: UILabel!
    @IBOutlet var buttonLabelCell: UITableViewCell!
    @IBOutlet var buttonLabelLabel: UILabel!
    @IBOutlet var buttonDismissBehaviorLabel: UILabel!
    @IBOutlet var borderRadiusLabel: UILabel!
    @IBOutlet var backgroundColorLabel: UILabel!
    @IBOutlet var borderColorLabel: UILabel!
    
    override func viewWillAppear(_ animated: Bool) {
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
