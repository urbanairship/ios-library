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
        let preferenceCenterAlertNib = UINib(nibName: "PreferenceCenterAlertCell", bundle:PreferenceCenterResources.bundle())
        tableView.register(preferenceCenterAlertNib, forCellReuseIdentifier: "PreferenceCenterAlertCell")
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
    
    // MARK: -
    // MARK: UITableViewDelegate
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        guard let sectionConfig = config?.sections[section] else {
            return nil
        }
        
        switch(sectionConfig.sectionType) {
        case .labeledSectionBreak:
            guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "PreferenceCenterSectionBreakHeader") as? PreferenceCenterSectionBreakHeader else {
                return nil
            }
            
            header.sectionBreakLabel.text = sectionConfig.display?.title
            header.sectionBreakView.backgroundColor = style?.sectionBreakBackgroundColor ?? .darkGray
            if let font = style?.sectionBreakTextFont {
                header.sectionBreakLabel.font = font
            }
            
            if let font = style?.sectionBreakTextFont {
                header.sectionBreakLabel.font = font
            }
            
            if let color = style?.sectionBreakTextColor {
                header.sectionBreakLabel.textColor = color
            }
            return header
            
        case .common:
            guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "PreferenceCenterSectionHeader") as? PreferenceCenterSectionHeader else {
                return nil
            }
            
            header.titleLabel.text = sectionConfig.display?.title
            header.subtitleLabel.text = sectionConfig.display?.subtitle
            if let font = style?.sectionTextFont {
                header.titleLabel.font = font
                header.subtitleLabel.font = font
            }
            
            if let color = style?.sectionTextColor {
                header.titleLabel.textColor = color
                header.subtitleLabel.textColor = color

            }
            return header
        }
    }
    
    // MARK: -
    // MARK: UITableViewDataSource
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        guard let sections = config?.sections.count else { return 0 }
        return sections
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let rows = config?.sections[section].items.count else { return 0 }
        return rows
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let defaultResult: () -> UITableViewCell =  {
            return tableView.dequeueReusableCell(withIdentifier: "PreferenceCenterCell", for: indexPath)
        }
        
        guard let item = config?.sections[indexPath.section].items[indexPath.row] else {
            return defaultResult()
        }
                                                                   
        switch(item.itemType) {
        case .channelSubscription:
            guard let item = item as? ChannelSubscriptionItem,
                  let cell = tableView.dequeueReusableCell(withIdentifier: "PreferenceCenterCell", for: indexPath) as? PreferenceCenterCell else {
                return defaultResult()
            }
            self.bindChannelSubscriptionItem(item, tableView: tableView, cell: cell)
            return cell
        case .alert:
            guard let item = item as? AlertItem,
                  let cell = tableView.dequeueReusableCell(withIdentifier: "PreferenceCenterAlertCell", for: indexPath) as? PreferenceCenterAlertCell else {
                return defaultResult()
            }
            self.bindAlertItem(item, tableView: tableView, cell: cell)
            return cell
        default:
            return defaultResult()
        }
    }
        
    private func bindAlertItem(_ item: AlertItem,
                               tableView: UITableView,
                               cell: PreferenceCenterAlertCell) {
        
        if let display = item.display {
            cell.alertTitle.text = display.title
            cell.alertDescription.text = display.subtitle ?? ""
            
            if let iconUrl = display.iconURL {
                if let url = URL(string: iconUrl) {
                    cell.alertIconIndicator.isHidden = false
                    cell.alertIconIndicator.startAnimating()
                    DispatchQueue.global().async {
                        let image = UIImage().loadImage(url: url, attempts: 3)
                        DispatchQueue.main.async {
                            cell.alertIconIndicator.stopAnimating()
                            cell.alertIconIndicator.isHidden = true
                            if (image != nil) {
                                cell.alertIcon.image = image
                                tableView.reloadData()
                            }
                        }
                    }
                }
            }
        }
        
        if let button = item.button {
            cell.alertButton.isHidden = false
            cell.alertButton.backgroundColor = .systemBlue
            cell.alertButton.layer.cornerRadius = 5
            cell.alertButton.setTitle(button.text, for: .normal)
            cell.alertButton.setTitleColor(.white, for: .normal)
            cell.alertButton.actions = button.actions
            cell.alertButton.addTarget(self, action: #selector(buttonAction(_:)), for: .touchUpInside)
            if button.contentDescription != nil {
                cell.alertButton.accessibilityLabel = button.contentDescription
            }
        } else {
            cell.alertButton.isHidden = true
        }
    }

    
    private func bindChannelSubscriptionItem(_ item: ChannelSubscriptionItem,
                                             tableView: UITableView,
                                             cell: PreferenceCenterCell) {
        cell.textLabel?.text = item.display?.title
        cell.detailTextLabel?.text = item.display?.subtitle
        cell.detailTextLabel?.numberOfLines = 0
        
        if let font = style?.preferenceTextFont {
            cell.textLabel?.font = font
            cell.detailTextLabel?.font = font
        }
        
        if let fontColor = style?.preferenceTextColor {
            cell.textLabel?.textColor = fontColor
            cell.detailTextLabel?.textColor = fontColor
        }
        
        if let backgroundColor = style?.backgroundColor {
            cell.backgroundColor = backgroundColor
        }
            
        guard let cellSwitch = cell.accessoryView as? UISwitch else {
            return
        }
        
        if let tintColor = style?.switchTintColor {
            cellSwitch.onTintColor = tintColor
        }
        
        if let thumbTintColor = style?.switchThumbTintColor {
            cellSwitch.thumbTintColor = thumbTintColor
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
    }

    // MARK: -
    // MARK:
    
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
    
    @objc func buttonAction(_ sender: AlertButton) {
        let actions = sender.actions as! Dictionary<String, Any>
        if (!actions.isEmpty) {
            for (name,value) in actions {
                ActionRunner.run(name, value: value, situation: .manualInvocation) { result in
                    print("Action finished!")
                    self.tableView.reloadData()
                }
            }
        }
    }
}

