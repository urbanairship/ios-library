/* Copyright 2010-2019 Urban Airship and Contributors */

import UIKit
import AirshipKit

class LastPayloadTableViewController: UITableViewController {

    @IBOutlet private weak var lastPushPayloadTextView: UITextView!
    @IBOutlet private weak var pushPayloadCell: UITableViewCell!

    let lastPushPayloadKey = "com.urbanairship.debug.last_push"
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        // Add refresh button
        let refreshButton: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(LastPayloadTableViewController.refreshView));
        
        navigationItem.rightBarButtonItem = refreshButton
    }

    func setCellTheme() {
        pushPayloadCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        lastPushPayloadTextView.backgroundColor = ThemeManager.shared.currentTheme.Background
        lastPushPayloadTextView.textColor = ThemeManager.shared.currentTheme.PrimaryText
    }

    func setTableViewTheme() {
        tableView.backgroundColor = ThemeManager.shared.currentTheme.Background;
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor:ThemeManager.shared.currentTheme.PrimaryText]
        navigationController?.navigationBar.barTintColor = ThemeManager.shared.currentTheme.NavigationBarBackground;
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setCellTheme()
        setTableViewTheme()
        refreshView()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @objc func refreshView() {
        guard let lastPushPayload = UserDefaults.standard.value(forKey: lastPushPayloadKey) else {
            self.lastPushPayloadTextView.text = "Payload is empty. Send a push notification!"
            return
        }

        self.lastPushPayloadTextView.text = (lastPushPayload as AnyObject).description
    }
}
