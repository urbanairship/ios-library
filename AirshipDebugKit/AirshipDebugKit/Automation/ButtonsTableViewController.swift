/* Copyright 2010-2019 Urban Airship and Contributors */

import UIKit
import AirshipKit

/**
 * The ButtonCell represents a single button cell
 * in the table.
 */
class ButtonCell: UITableViewCell {
    @IBOutlet var buttonID: UILabel!
    @IBOutlet var buttonBehavior: UILabel!
    
    var button : UAInAppMessageButtonInfo?
}

/**
 * The ButtonsTableViewController displays a list of IAA message buttons.
 */
class ButtonsTableViewController: UITableViewController {
    public static let segueID = "ShowButtonsTable"

    /* The UAInAppMessageButtonInfos to be displayed. */
    public var buttons : [ UAInAppMessageButtonInfo ]?
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return buttons?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ButtonCell", for: indexPath) as! ButtonCell

        // Clear the cell
        cell.button = nil
        cell.buttonID.text = nil
        cell.buttonBehavior.text = nil
        
        if let button = self.buttons?[indexPath.row] {
            cell.button = button
            
            cell.buttonID.text = button.identifier
            switch button.behavior {
            case .dismiss:
                cell.buttonBehavior.text = "ua_button_behavior_dismiss".localized()
            case .cancel:
                cell.buttonBehavior.text = "ua_button_behavior_cancel".localized()
            }
        }

        return cell
    }

    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        switch(segue.identifier ?? "") {
        case ButtonDetailViewController.segueID:
            guard let buttonDetailViewController = segue.destination as? ButtonDetailViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }
            
            guard let selectedButtonCell = sender as? ButtonCell else {
                fatalError("Unexpected sender: \(sender ?? "unknown sender")")
            }
            
            buttonDetailViewController.button = selectedButtonCell.button
        default:
            print("ERROR: Unexpected Segue Identifier; \(segue.identifier ?? "unknown identifier")")
        }
    }
}

