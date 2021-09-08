/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
import AirshipAutomation
#elseif canImport(Airship)
import Airship
#endif

class DeferredDetailViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet var tableView: UITableView!
    
    public static let segueID = "DeferredDetailSegue"
    
    /* The UASchedule to be displayed */
    public var schedule : DeferredSchedule?
    
    var collapsedCellPaths:[IndexPath] = []
    
    /* Section
     * Note: Number of sections and sections for row are defined in their respective
     * table view data source methods
     */
    let messageSection = 0

    // Indexes section 0
    let nameIdx = IndexPath(row: 0, section: 0)
    
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
            return 1
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

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case messageSection:
            return "ua_message_title".localized()
        default:
            return "ua_displaycontent_title_unknown".localized()
        }
    }
    
    func createMessageCell(_ indexPath:IndexPath) -> UITableViewCell {
        guard let schedule = schedule else {
            return UITableViewCell()
        }

        let cell = defaultDeferredDetailCell(indexPath)

        switch indexPath {
        case nameIdx:
            cell.title.text = "ua_message_url".localized()
            cell.subtitle.text = schedule.deferredData.url.absoluteString
        default:
            break
        }

        return cell
    }
    
    func defaultDeferredDetailCell(_ indexPath:IndexPath) -> AutomationDetailCell {
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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        switch(segue.identifier ?? "") {
        default:
            print("ERROR: Unexpected Segue Identifier; \(segue.identifier ?? "unknown identifier")")
        }
    }
    
}
