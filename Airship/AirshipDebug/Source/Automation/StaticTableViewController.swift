/* Copyright Airship and Contributors */

import UIKit

/**
 * The StaticTableViewController handles the basic functions
 * of an IAA detail view controller. Individual IAA detail view
 * controllers subclass this controller.
 *
 * Note: most of this code enables the hiding of unused cells
 * in a static table.
 */
class StaticTableViewController: UITableViewController {

    private var cellsToHide : Set<UITableViewCell> = Set()
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cell = self.tableView(tableView, cellForRowAt: indexPath)
        if self.cellsToHide.contains(cell) {
            return 0
        } else {
            return UITableView.automaticDimension
        }
    }

    func setTableViewTheme() {
        tableView.backgroundColor = ThemeManager.shared.currentTheme.Background;
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setTableViewTheme()
    }
    
    func heightForCell(_ cell: UITableViewCell, resizingLabel: UILabel) -> CGFloat {
        cell.layoutIfNeeded()
        if (resizingLabel.frame.size.height < resizingLabel.intrinsicContentSize.height) {
            return cell.frame.size.height + resizingLabel.intrinsicContentSize.height - resizingLabel.frame.size.height
        }
        return cell.frame.size.height
    }
    
    func updateOrHideCell(_ cell : UITableViewCell, label : UILabel, newText : String?) {
        if let newText = newText {
            // set text and show cell
            label.text = newText
            showCell(cell)
            cell.isHidden = false
        } else {
            // HIDE cell
            hideCell(cell)
            cell.isHidden = true
        }
    }
    
    func hideCell(_ cell : UITableViewCell) {
        cellsToHide.insert(cell)
    }

    func showCell(_ cell : UITableViewCell) {
        cellsToHide.remove(cell)
    }
}
