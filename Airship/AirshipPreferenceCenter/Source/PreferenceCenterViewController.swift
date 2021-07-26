/* Copyright Airship and Contributors */

import UIKit
#if canImport(AirshipCore)
import AirshipCore
#endif

/**
 * Preference Center view controller.
 */
open class PreferenceCenterViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
   
    @IBOutlet private var tableView: UITableView!
    @IBOutlet private var overlayView: UIView!
    @IBOutlet private var activityIndicator: UIActivityIndicatorView!
    private var config: PreferenceCenterConfig?
    private var preferenceCenterId: String?
    
    init(identifier: String, nibName: String?, bundle:Bundle?) {
        self.preferenceCenterId = identifier
        super.init(nibName: nibName, bundle: bundle)        
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()

        overlayView.alpha = 1;
        activityIndicator.startAnimating()
        
        tableView.register(UINib(nibName: "PreferenceCenterCell", bundle: PreferenceCenterResources.bundle()), forCellReuseIdentifier: "PreferenceCenterCell")

        tableView.delegate = self
        tableView.dataSource = self
        
        onConfigUpdated()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(false)
        
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
       
    }
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        guard let sections = config?.sections.count else { return 0 }
        return sections
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let rows = config?.sections[section].items.count else { return 0 }
        return rows
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
       
        let cell = tableView.dequeueReusableCell(withIdentifier: "PreferenceCenterCell", for: indexPath) as! PreferenceCenterCell

        cell.textLabel?.text = config?.sections[indexPath.section].items[indexPath.row].display?.title
        cell.detailTextLabel?.text = config?.sections[indexPath.section].items[indexPath.row].display?.subtitle
      
        cell.callback = { isOn in
            // Apply changes to subscription items
        }
        
        return cell
    }

    func onConfigUpdated() {
        PreferenceCenter.shared().config(preferenceCenterID: self.preferenceCenterId!) { config in
            
            if (config == nil) {
                return
            }
            
            self.config = config
            self.title = config?.display?.title
            
            self.overlayView.alpha = 0;
            self.activityIndicator.stopAnimating()
            
            self.reload()
        }
    }
    
    func reload() {
        tableView.reloadData()

        // Recompute layout so that sizes are correct
        tableView.invalidateIntrinsicContentSize()
        tableView.layoutIfNeeded()
    }
}

