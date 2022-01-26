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
    private var activeSubscriptions: [String] = []
    private var disposable: Disposable?
    public var preferenceCenterID: String?
    
    /**
     * Preference center style
     */
    @objc
    public var style: PreferenceCenterStyle?
    
    init(identifier: String, nibName: String?, bundle:Bundle?) {
        self.preferenceCenterID = identifier
        super.init(nibName: nibName, bundle: bundle)        
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(nibName: "PreferenceCenterViewController", bundle: PreferenceCenterResources.bundle())
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(PreferenceCenterCell.self, forCellReuseIdentifier: "PreferenceCenterCell")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = style?.backgroundColor
        if #available(iOS 15.0, macOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0.0
        }
        
        let headerView = PreferenceCenterHeaderLabel(frame: CGRect.zero)
        headerView.numberOfLines = 0
        headerView.lineBreakMode = .byWordWrapping
        self.tableView.tableHeaderView = headerView
       
        let sectionHeaderNib = UINib(nibName: "PreferenceCenterSectionHeader", bundle:PreferenceCenterResources.bundle())
        tableView.register(sectionHeaderNib, forHeaderFooterViewReuseIdentifier: "PreferenceCenterSectionHeader")
        
        let sectionBreakHeaderNib = UINib(nibName: "PreferenceCenterSectionBreakHeader", bundle:PreferenceCenterResources.bundle())
        tableView.register(sectionBreakHeaderNib, forHeaderFooterViewReuseIdentifier: "PreferenceCenterSectionBreakHeader")
        
        refreshConfig()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(false)
        
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.disposable?.dispose()
    }
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        guard let sections = config?.sections.count else { return 0 }
        return sections
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let rows = config?.sections[section].items.count else { return 0 }
        return rows
    }
    
    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if(config?.sections[section].type == SectionType.sectionBreak.rawValue) {
            let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "PreferenceCenterSectionBreakHeader") as! PreferenceCenterSectionBreakHeader
            header.sectionBreakLabel.text = config?.sections[section].display?.title
            if (style?.sectionBreakBackgroundColor != nil) {
                header.sectionBreakView.backgroundColor = style?.sectionBreakBackgroundColor
            } else {
                header.sectionBreakView.backgroundColor = .darkGray
            }
            if (style?.sectionBreakTextFont != nil) {
                header.sectionBreakLabel.font = style?.sectionBreakTextFont
            }
            if (style?.sectionBreakTextColor != nil) {
                header.sectionBreakLabel.textColor = style?.sectionBreakTextColor
            }
            return header
        } else {
            let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "PreferenceCenterSectionHeader") as! PreferenceCenterSectionHeader
            header.titleLabel.text = config?.sections[section].display?.title
            header.subtitleLabel.text = config?.sections[section].display?.subtitle
            if (style?.sectionTextFont != nil) {
                header.titleLabel.font = style?.sectionTextFont
                header.subtitleLabel.font = style?.sectionTextFont
            }
            if (style?.sectionTextColor != nil) {
                header.titleLabel.textColor = style?.sectionTextColor
                header.subtitleLabel.textColor = style?.sectionTextColor
            }
            return header
        }
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
       
        let cell = tableView.dequeueReusableCell(withIdentifier: "PreferenceCenterCell", for: indexPath) as!
                PreferenceCenterCell
        
        guard let item = config?.sections[indexPath.section].items[indexPath.row] as? ChannelSubscriptionItem else {
            return cell
        }
        
        cell.textLabel?.text = item.display?.title
        cell.detailTextLabel?.text = item.display?.subtitle
        if (style?.preferenceTextFont != nil) {
            cell.textLabel?.font = style?.preferenceTextFont
            cell.detailTextLabel?.font = style?.preferenceTextFont
        }
        if (style?.preferenceTextColor != nil) {
            cell.textLabel?.textColor = style?.preferenceTextColor
            cell.detailTextLabel?.textColor = style?.preferenceTextColor
        }
        if (style?.backgroundColor != nil) {
            cell.backgroundColor = style?.backgroundColor
        }
            
        cell.detailTextLabel?.numberOfLines = 0
        
        let cellSwitch = cell.accessoryView as! UISwitch
        if let tintColor = style?.switchTintColor {
            cellSwitch.onTintColor = tintColor
        }
        
        if let tintColor = style?.switchThumbTintColor {
            cellSwitch.thumbTintColor = tintColor
        }
        
        if (activeSubscriptions.contains(item.subscriptionID)) {
            cellSwitch.setOn(true, animated: false)
        } else {
            cellSwitch.setOn(false, animated: false)
        }
        
        cell.callback = { isOn in
            let editor = Airship.channel.editSubscriptionLists()
            if (isOn) {
                self.activeSubscriptions.append(item.subscriptionID)
                editor.subscribe(item.subscriptionID)
            } else {
                self.activeSubscriptions.removeAll(where: { $0 == item.subscriptionID })
                editor.unsubscribe(item.subscriptionID)
            }
            
            editor.apply()
            tableView.reloadData()
        }
        
        return cell
    }

    func onConfigLoaded(config: PreferenceCenterConfig, lists: [String]) {
        self.config = config
        self.navigationItem.title = style?.title ?? config.display?.title ?? PreferenceCenterResources.localizedString(key: "ua_preference_center_title")
       
        let headerView = self.tableView.tableHeaderView as! PreferenceCenterHeaderLabel

        if let description = style?.subtitle ?? config.display?.subtitle {
            headerView.isHidden = false
            headerView.text = description
            if let font = style?.subtitleFont {
                headerView.font = font
            }
            
            if let color = style?.subtitleColor {
                headerView.textColor = color
            }
            headerView.leadingPadding = 15
            headerView.trailingPadding = 10
            headerView.topPadding = 10
            headerView.bottomPadding = 10
            
            headerView.resize()
        } else {
            headerView.isHidden = true
        }
    
        self.overlayView.alpha = 0;
        self.activityIndicator.stopAnimating()
        self.activeSubscriptions = lists
        self.refreshTable()
    }
    
    func refreshConfig() {
        overlayView.alpha = 1;
        activityIndicator.startAnimating()
        
        self.disposable?.dispose()
        
        var onComplete : ((PreferenceCenterConfig, [String]) -> Void)? = { config, lists in
            self.onConfigLoaded(config: config, lists: lists)
        }
        
        guard let preferenceCenterID = self.preferenceCenterID else {
            return
        }
        
        var cancelled = false
    
        self.disposable = Disposable {
            cancelled = true
            onComplete = nil
        }
        
        Airship.channel.fetchSubscriptionLists() { [weak self] subscribedIDs, error in
            
            guard error == nil, let subscribedIDs = subscribedIDs else {
                UADispatcher.main.dispatch(after: 30, block: {
                    if (!cancelled) {
                        self?.refreshConfig()
                    }
                })
                return
            }
            
            PreferenceCenter.shared.config(preferenceCenterID: preferenceCenterID) { config in
                guard let config = config else {
                    UADispatcher.main.dispatch(after: 30, block: {
                        if (!cancelled) {
                            self?.refreshConfig()
                        }
                    })
                    return
                }
                
                UADispatcher.main.dispatchAsync {
                    onComplete?(config, subscribedIDs)
                }
                
            }
        }
    }
    
    func refreshTable() {
        tableView.reloadData()

        // Recompute layout so that sizes are correct
        tableView.invalidateIntrinsicContentSize()
        tableView.layoutIfNeeded()
    }
}

