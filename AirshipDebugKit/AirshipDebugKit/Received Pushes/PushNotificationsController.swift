/* Copyright Airship and Contributors */

import UIKit
import AirshipKit

class PushNotificationsCell: UITableViewCell {
    @IBOutlet weak var alertTitle: UILabel!
    @IBOutlet weak var messageID: UILabel!
    @IBOutlet weak var messageDate: UILabel!
}

class PushNotificationsController:UIViewController, UITableViewDataSource, UITableViewDelegate, PushDataManagerDelegate {
        @IBOutlet private weak var tableView:UITableView!
//        @IBOutlet private weak var searchFooter:SearchFooter!

        @IBOutlet var navAddButton: UIBarButtonItem!
        @IBOutlet var storageOptionsButton: UIBarButtonItem!

        var launchPathComponents : [String]?
        var launchCompletionHandler : (() -> Void)?

        let defaultPushNotificationCellHeight:CGFloat = 64

        var detailViewController:PushNotificationsDetailTableViewController? = nil
        var totalPushesCount = 0;
        var displayPushes = [PushNotification]()
//        let searchController = UISearchController(searchResultsController:nil)

//        let currentSearchString:String? = nil
        let currentTimeWindow:TimeWindow = .All

        func pushAdded() {
//            displayEvents = PushDataManager.shared.fetchEventsContaining(searchString:currentSearchString, timeWindow:timeWindowToDateInterval(timeWindow:currentTimeWindow))
            displayPushes = PushDataManager.shared.fetchPushesContaining()

            totalPushesCount += 1
            tableView.reloadData()
        }

        func setTableViewTheme() {
            tableView.backgroundColor = ThemeManager.shared.currentTheme.Background;
            navigationController?.navigationBar.titleTextAttributes = [.foregroundColor:ThemeManager.shared.currentTheme.NavigationBarText]
            navigationController?.navigationBar.barTintColor = ThemeManager.shared.currentTheme.NavigationBarBackground;
        }

        override func viewDidLoad() {
            super.viewDidLoad()

//            searchController.searchResultsUpdater = self
//            searchController.obscuresBackgroundDuringPresentation = false
//            searchController.searchBar.placeholder = "Search Events"

//            if #available(iOS 11.0, *) {
//                navigationItem.searchController = searchController
//                navigationItem.hidesSearchBarWhenScrolling = false
//            } else {
//                tableView.tableHeaderView = searchController.searchBar
//            }

            definesPresentationContext = true

//            searchController.searchBar.scopeButtonTitles = [TimeWindow.All.rawValue,
//                                                            TimeWindow.LastHour.rawValue,
//                                                            TimeWindow.Today.rawValue,
//                                                            TimeWindow.Yesterday.rawValue]

//            searchController.searchBar.searchBarStyle = .prominent
//            searchController.searchBar.showsScopeBar = false
//            searchController.searchBar.tintColor = ThemeManager.shared.currentTheme.NavigationBarText
//            searchController.searchBar.barTintColor = ThemeManager.shared.currentTheme.NavigationBarText

//            searchController.searchBar.delegate = self
            tableView.delegate = self
            tableView.dataSource = self

//            tableView.tableFooterView = searchFooter

            PushDataManager.shared.delegate = self;

            // Initially fetch all events for correct total event count
            displayPushes = PushDataManager.shared.fetchAllPushNotifications()
            totalPushesCount = displayPushes.count
            tableView.reloadData()
        }

        @IBAction func showOptions() {
            let actionSheet = UIAlertController(title:"Set Storage Days", message:"For how many days would you like events to be tracked? Current storage days: \(PushDataManager.shared.storageDays)", preferredStyle:.actionSheet)

            let actionInfos = ["2 Days": 2, "5 Days": 5, "10 Days": 10, "30 Days": 30]

            for (title, days) in actionInfos {
                actionSheet.addAction(UIAlertAction(title:title, style:.default, handler:{ (action) in
                    PushDataManager.shared.storageDays = days
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

        override func viewWillLayoutSubviews() {
            super.viewWillLayoutSubviews()
//            searchController.searchBar.setSearchTheme(color: ThemeManager.shared.currentTheme.SecondaryText)
        }

        override func didReceiveMemoryWarning() {
            super.didReceiveMemoryWarning()
        }

        func numberOfSections(in tableView:UITableView) -> Int {
            return 1
        }

        func tableView(_ tableView:UITableView, numberOfRowsInSection section:Int) -> Int {
//            if isFiltering() {
//                searchFooter.setIsFilteringToShow(filteredItemCount:displayPushes.count, of:totalPushesCount)
//                return displayPushes.count
//            }
//
//            searchFooter.setNotFiltering()
            return displayPushes.count
        }

        func tableView(_ tableView:UITableView, cellForRowAt indexPath:IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier:"PushNotificationsCell", for:indexPath) as! PushNotificationsCell
            let push:PushNotification

            push = displayPushes[indexPath.row]

            cell.alertTitle.text = push.alert
            cell.alertTitle.textColor = ThemeManager.shared.currentTheme.SecondaryText
            cell.messageDate.text = push.time.toPrettyDateString()
            cell.messageDate.textColor = ThemeManager.shared.currentTheme.PrimaryText
            cell.messageID.text = push.pushID
            cell.messageID.textColor = ThemeManager.shared.currentTheme.SecondaryText
            cell.backgroundColor = ThemeManager.shared.currentTheme.Background

            return cell
        }

        func tableView(_ tableView:UITableView, heightForRowAt indexPath:IndexPath) -> CGFloat {
            return defaultPushNotificationCellHeight
        }

        override func prepare(for segue:UIStoryboardSegue, sender:Any?) {
            if segue.identifier == "pushDetailSegue" {
                if let indexPath = tableView.indexPathForSelectedRow {
                    let push:PushNotification
                    push = displayPushes[indexPath.row]
                    let controller = segue.destination as! PushNotificationsDetailTableViewController
                    controller.push = push
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

//        func filterContentForSearchText(_ search:String, timeWindow:TimeWindow) {
//            self.displayEvents = PushDataManager.shared.fetchEventsContaining(searchString:search, timeWindow:timeWindowToDateInterval(timeWindow:timeWindow))
//            self.displayPushes = PushDataManager.shared.fetchPushesContaining()
//            tableView.reloadData()
//        }

//        func searchBarIsEmpty() -> Bool {
//            return searchController.searchBar.text?.isEmpty ?? true
//        }
//
//        func isFiltering() -> Bool {
//            let searchBarScopeIsFiltering = searchController.searchBar.selectedScopeButtonIndex != 0
//            return searchController.isActive && (!searchBarIsEmpty() || searchBarScopeIsFiltering)
//        }
    }

//    extension EventsViewController:UISearchBarDelegate {
//        func searchBar(_ searchBar:UISearchBar, selectedScopeButtonIndexDidChange selectedScope:Int) {
//            filterContentForSearchText(searchBar.text!, timeWindow:scopeTitleToTimeWindow(title:searchBar.scopeButtonTitles![selectedScope]))
//        }
//    }

//    extension ReceivedPushesTableViewController:UISearchResultsUpdating {
//        func updateSearchResults(for searchController:UISearchController) {
//            let searchBar = searchController.searchBar
//            let scope = scopeTitleToTimeWindow(title:searchBar.scopeButtonTitles![searchBar.selectedScopeButtonIndex])
//            filterContentForSearchText(searchController.searchBar.text!, timeWindow:scope)
//        }
//    }

//    extension UISearchBar {

//        func getSearchField() -> UITextField? {
//            return self.value(forKey: "searchField") as? UITextField
//        }
//
//        func setSearchTheme(color: UIColor) {
//            setTextColor(color: color)
//            setPlaceholderTextColor(color: color)
//            setMagnifyingGlassColorTo(color: color)
//            setClearButtonColorTo(color: color)
//        }
//
//        func setTextColor(color: UIColor) {
//            let textFieldInsideSearchBar = getSearchField()
//            textFieldInsideSearchBar?.textColor = color
//        }
//
//        func setPlaceholderTextColor(color: UIColor) {
//            guard let textFieldInsideSearchBar = getSearchField() else { return }
//            let textFieldInsideSearchBarLabel = textFieldInsideSearchBar.value(forKey: "placeholderLabel") as? UILabel
//            textFieldInsideSearchBarLabel?.textColor = color
//        }
//
//        func setMagnifyingGlassColorTo(color: UIColor) {
//            let textFieldInsideSearchBar = getSearchField()
//            let glassIconView = textFieldInsideSearchBar?.leftView as? UIImageView
//            glassIconView?.image = glassIconView?.image?.withRenderingMode(.alwaysTemplate)
//            glassIconView?.tintColor = color
//        }
//
//        func setClearButtonColorTo(color: UIColor) {
//            let textFieldInsideSearchBar = getSearchField()
//            let crossIconView = textFieldInsideSearchBar?.value(forKey: "clearButton") as? UIButton
//            crossIconView?.setImage(crossIconView?.currentImage?.withRenderingMode(.alwaysTemplate), for: .normal)
//            crossIconView?.tintColor = color
//        }
//    }
