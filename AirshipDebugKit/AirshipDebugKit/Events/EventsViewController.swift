/* Copyright Urban Airship and Contributors */

import UIKit
import AirshipKit

enum TimeWindow:String {
    case All = "All"
    case LastHour = "Last Hour"
    case Today = "Today"
    case Yesterday = "Yesterday"
}

class EventCell:UITableViewCell {
    @IBOutlet weak var eventType:UILabel!
    @IBOutlet weak var eventID:UILabel!
    @IBOutlet weak var time:UILabel!
}

class EventsViewController:UIViewController, UITableViewDataSource, UITableViewDelegate, EventDataManagerDelegate {
    @IBOutlet private weak var tableView:UITableView!
    @IBOutlet private weak var searchFooter:SearchFooter!

    @IBOutlet var navAddButton: UIBarButtonItem!
    @IBOutlet var storageOptionsButton: UIBarButtonItem!

    var launchPathComponents : [String]?
    var launchCompletionHandler : (() -> Void)?

    let defaultEventCellHeight:CGFloat = 64

    var detailViewController:EventsDetailTableViewController? = nil
    var totalEventsCount = 0;
    var displayEvents = [Event]()
    let searchController = UISearchController(searchResultsController:nil)

    let currentSearchString:String? = nil
    let currentTimeWindow:TimeWindow = .All

    func eventAdded() {
        displayEvents = EventDataManager.shared.fetchEventsContaining(searchString:currentSearchString, timeWindow:timeWindowToDateInterval(timeWindow:currentTimeWindow))

        totalEventsCount += 1
        tableView.reloadData()
    }

    func setTableViewTheme() {
        tableView.backgroundColor = ThemeManager.shared.currentTheme.Background;
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor:ThemeManager.shared.currentTheme.PrimaryText]
        navigationController?.navigationBar.barTintColor = ThemeManager.shared.currentTheme.NavigationBarBackground;
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search Events"

        if #available(iOS 11.0, *) {
            navigationItem.searchController = searchController
            navigationItem.hidesSearchBarWhenScrolling = false
        } else {
            tableView.tableHeaderView = searchController.searchBar
        }

        definesPresentationContext = true

        searchController.searchBar.scopeButtonTitles = [TimeWindow.All.rawValue,
                                                        TimeWindow.LastHour.rawValue,
                                                        TimeWindow.Today.rawValue,
                                                        TimeWindow.Yesterday.rawValue]

        searchController.searchBar.searchBarStyle = .prominent
        searchController.searchBar.showsScopeBar = false
        searchController.searchBar.tintColor = #colorLiteral(red: 0.5333333333, green: 0.7137254902, blue: 0.7843137255, alpha: 1)

        searchController.searchBar.delegate = self
        tableView.delegate = self
        tableView.dataSource = self

        tableView.tableFooterView = searchFooter

        EventDataManager.shared.delegate = self;

        // Initially fetch all events for correct total event count
        displayEvents = EventDataManager.shared.fetchAllEvents()
        totalEventsCount = displayEvents.count
        tableView.reloadData()
    }

    @IBAction func showOptions() {
        let actionSheet = UIAlertController(title:"Set Storage Days", message:"For how many days would you like events to be tracked? Current storage days: \(EventDataManager.shared.storageDays)", preferredStyle:.actionSheet)

        let actionInfos = ["2 Days": 2, "5 Days": 5, "10 Days": 10, "30 Days": 30]

        for (title, days) in actionInfos {
            actionSheet.addAction(UIAlertAction(title:title, style:.default, handler:{ (action) in
                EventDataManager.shared.storageDays = days
                self.dismiss(animated:true)
            }))
        }

        actionSheet.addAction(UIAlertAction(title:"Cancel", style:.cancel, handler:{ action in
            // Cancel button tappped.
            self.dismiss(animated:true)
        }))

        actionSheet.popoverPresentationController?.sourceView = self.view
        present(actionSheet, animated:true)
    }

    override func viewWillAppear(_ animated:Bool) {
        super.viewWillAppear(animated)

        if let selectionIndexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at:selectionIndexPath, animated:animated)
        }

        setTableViewTheme()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func numberOfSections(in tableView:UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView:UITableView, numberOfRowsInSection section:Int) -> Int {
        if isFiltering() {
            searchFooter.setIsFilteringToShow(filteredItemCount:displayEvents.count, of:totalEventsCount)
            return displayEvents.count
        }

        searchFooter.setNotFiltering()
        return displayEvents.count
    }

    func tableView(_ tableView:UITableView, cellForRowAt indexPath:IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier:"EventCell", for:indexPath) as! EventCell
        let event:Event

        event = displayEvents[indexPath.row]

        cell.eventID.text = event.eventID
        cell.eventID.textColor = ThemeManager.shared.currentTheme.SecondaryText
        cell.eventType.text = event.eventType
        cell.eventType.textColor = ThemeManager.shared.currentTheme.PrimaryText
        cell.time.text = event.time.toPrettyDateString()
        cell.time.textColor = ThemeManager.shared.currentTheme.SecondaryText
        cell.backgroundColor = ThemeManager.shared.currentTheme.Background

        return cell
    }

    func tableView(_ tableView:UITableView, heightForRowAt indexPath:IndexPath) -> CGFloat {
        return defaultEventCellHeight
    }

    override func prepare(for segue:UIStoryboardSegue, sender:Any?) {
        if segue.identifier == "eventDetailSegue" {
            if let indexPath = tableView.indexPathForSelectedRow {
                let event:Event
                event = displayEvents[indexPath.row]
                let controller = segue.destination as! EventsDetailTableViewController
                controller.event = event
            }
        }
    }

    func timeWindowToDateInterval(timeWindow:TimeWindow) -> DateInterval? {
        let hourInSeconds:Double = 3600
        let dayInSeconds:Double = 86400

        let startOfToday = Calendar.current.startOfDay(for:Date())
        let yesterday = Calendar.current.date(byAdding:.day, value:-1, to:startOfToday)!
        let lastHour = Calendar.current.date(byAdding:.hour, value:-1, to:Date())!

        switch timeWindow {
        case .All:
            return nil
        case .LastHour:
            return DateInterval(start:lastHour, duration:hourInSeconds)
        case .Today:
            return DateInterval(start:startOfToday, duration:dayInSeconds)
        case .Yesterday:
            return DateInterval(start:yesterday, duration:dayInSeconds)
        }
    }

    func scopeTitleToTimeWindow(title:String) -> TimeWindow {
        switch title {
        case TimeWindow.LastHour.rawValue:
            return .LastHour
        case TimeWindow.Today.rawValue:
            return .Today
        case TimeWindow.Yesterday.rawValue:
            return .Yesterday
        default:
            return .All
        }
    }

    func filterContentForSearchText(_ search:String, timeWindow:TimeWindow) {
        self.displayEvents = EventDataManager.shared.fetchEventsContaining(searchString:search, timeWindow:timeWindowToDateInterval(timeWindow:timeWindow))
        tableView.reloadData()
    }

    func searchBarIsEmpty() -> Bool {
        return searchController.searchBar.text?.isEmpty ?? true
    }

    func isFiltering() -> Bool {
        let searchBarScopeIsFiltering = searchController.searchBar.selectedScopeButtonIndex != 0
        return searchController.isActive && (!searchBarIsEmpty() || searchBarScopeIsFiltering)
    }
}

extension EventsViewController:UISearchBarDelegate {
    func searchBar(_ searchBar:UISearchBar, selectedScopeButtonIndexDidChange selectedScope:Int) {
        filterContentForSearchText(searchBar.text!, timeWindow:scopeTitleToTimeWindow(title:searchBar.scopeButtonTitles![selectedScope]))
    }
}

extension EventsViewController:UISearchResultsUpdating {
    func updateSearchResults(for searchController:UISearchController) {
        let searchBar = searchController.searchBar
        let scope = scopeTitleToTimeWindow(title:searchBar.scopeButtonTitles![searchBar.selectedScopeButtonIndex])
        filterContentForSearchText(searchController.searchBar.text!, timeWindow:scope)
    }
}
