/* Copyright 2010-2019 Urban Airship and Contributors */

import UIKit
import AirshipKit

class LastPayloadTableViewController: UITableViewController {

    @IBOutlet var lastPushPayloadTextView: UITextView!
    
    let lastPushPayloadKey = "com.urbanairship.debug.last_push"
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        // Add refresh button
        let refreshButton: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(LastPayloadTableViewController.refreshView));
        
        navigationItem.rightBarButtonItem = refreshButton
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated);
    }

    override func viewWillAppear(_ animated: Bool) {
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
