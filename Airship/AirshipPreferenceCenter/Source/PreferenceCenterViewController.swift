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
    private var filteredSections: [PreferenceCenterFilteredSection]?
    private var activeChannelSubscriptions: [String] = []
    private var activeContactSubscriptions: [String : [ChannelScope]] = [:]
    private var disposable: Disposable?
    public var preferenceCenterID: String? {
        didSet {
            shouldRefresh = true
            if (self.isViewLoaded) {
                refreshConfig()
            }
        }
    }
    
    private var shouldRefresh = true
    private var conditionStateMonitor: PreferenceCenterConditionMonitor?
    private var imageCache: [URL: UIImage] = [:]
    private var imageCompletionHandlers: [URL: [(UIImage?) -> Void]] = [:]

    /**
     * Preference center style
     */
    @objc
    public var style: PreferenceCenterStyle?
    
    @objc
    public init(identifier: String) {
        self.preferenceCenterID = identifier
        super.init(nibName: "PreferenceCenterViewController", bundle: PreferenceCenterResources.bundle())
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(nibName: "PreferenceCenterViewController", bundle: PreferenceCenterResources.bundle())
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        self.conditionStateMonitor = PreferenceCenterConditionMonitor { [weak self] in
            self?.updatePreferenceCenter()
        }
        
        tableView.register(PreferenceCenterCell.self, forCellReuseIdentifier: "PreferenceCenterCell")
        let preferenceCenterAlertNib = UINib(nibName: "PreferenceCenterAlertCell", bundle:PreferenceCenterResources.bundle())
        tableView.register(preferenceCenterAlertNib, forCellReuseIdentifier: "PreferenceCenterAlertCell")
        tableView.register(PreferenceCenterCheckboxCell.self, forCellReuseIdentifier: "PreferenceCenterCheckboxCell")
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

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(false)
        
        if (self.shouldRefresh) {
            refreshConfig()
        }
    }

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.disposable?.dispose()
    }
    
    // MARK: -
    // MARK: UITableViewDelegate
    
    open func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let sectionConfig = self.filteredSections?[section].section else {
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

            if let font = style?.sectionTitleTextFont ?? style?.sectionTextFont {
                header.titleLabel.font = font
            }
            
            if let color = style?.sectionTitleTextColor ?? style?.sectionTextColor {
                header.titleLabel.textColor = color
            }

            if let font = style?.sectionSubtitleTextFont ?? style?.sectionTextFont {
                header.subtitleLabel.font = font
            }
            
            if let color = style?.sectionSubtitleTextColor ?? style?.sectionTextColor {
                header.subtitleLabel.textColor = color
            }
            
            return header
        }
    }
    
    // MARK: -
    // MARK: UITableViewDataSource
    
    open func numberOfSections(in tableView: UITableView) -> Int {
        guard let sections = filteredSections?.count else { return 0 }
        return sections
    }
    
    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let rows = filteredSections?[section].items.count else { return 0 }
        return rows
    }
    
    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let defaultResult: () -> UITableViewCell =  {
            return tableView.dequeueReusableCell(withIdentifier: "PreferenceCenterCell", for: indexPath)
        }
        
        guard let item = self.filteredSections?[indexPath.section].items[indexPath.row] else {
            return defaultResult()
        }
                               
        var cell: UITableViewCell?
        switch(item.itemType) {
        case .channelSubscription:
            cell = self.bindChannelSubscriptionItem(item,
                                                    tableView: tableView,
                                                    indexPath: indexPath)
        case .alert:
            cell = self.bindAlertItem(item,
                                      tableView: tableView,
                                      indexPath: indexPath)
            
        case .contactSubscription:
            cell = self.bindContactSubscriptionItem(item,
                                                    tableView: tableView,
                                                    indexPath: indexPath)
        case .contactSubscriptionGroup:
            cell = self.bindContactGroupSubscriptionItem(item,
                                                    tableView: tableView,
                                                    indexPath: indexPath)
        }

        return cell ?? defaultResult()
    }
        
    private func bindAlertItem(_ item: Item,
                               tableView: UITableView,
                               indexPath: IndexPath) -> UITableViewCell? {
        
        guard let item = item as? AlertItem, let cell = tableView.dequeueReusableCell(withIdentifier: "PreferenceCenterAlertCell", for: indexPath) as? PreferenceCenterAlertCell else {
            return nil
        }
            
        if let display = item.display {
            cell.alertTitle.text = display.title
            cell.alertDescription.text = display.subtitle ?? ""
            
            if let font = style?.alertTitleFont {
                cell.alertTitle?.font = font
            }
            
            if let fontColor = style?.alertTitleColor {
                cell.alertTitle?.textColor = fontColor
            }
            
            if let font = style?.alertSubtitleFont {
                cell.alertDescription?.font = font
            }
            
            if let fontColor = style?.alertSubtitleColor {
                cell.alertDescription?.textColor = fontColor
            }
            
            if let iconUrl = display.iconURL, let url = URL(string: iconUrl) {
                cell.alertIconIndicator.startAnimating()
                
                self.fetchImage(url: url) { image in
                    cell.alertIconIndicator.stopAnimating()
                    if (image != nil) {
                        cell.alertIcon.image = image
                        self.refreshTable()
                    }
                }
                
            } else {
                cell.alertIconIndicator.stopAnimating()
            }
        }
        
        if let button = item.button {
            cell.alertButton.isHidden = false
            cell.alertButton.backgroundColor = self.style?.alertButtonBackgroundColor ?? .systemBlue
            cell.alertButton.layer.cornerRadius = 5
            if let font = style?.alertButtonLabelFont {
                cell.alertButton.titleLabel?.font = font
            }
            cell.alertButton.setTitle(button.text, for: .normal)
            cell.alertButton.setTitleColor(self.style?.alertButtonLabelColor ?? .white, for: .normal)
            cell.alertButton.actions = button.actions
            cell.alertButton.addTarget(self, action: #selector(buttonAction(_:)), for: .touchUpInside)
            if button.contentDescription != nil {
                cell.alertButton.accessibilityLabel = button.contentDescription
            }
        } else {
            cell.alertButton.isHidden = true
        }
        
        return cell
    }

    
    private func bindChannelSubscriptionItem(_ item: Item,
                                             tableView: UITableView,
                                             indexPath: IndexPath) -> UITableViewCell? {
        guard let item = item as? ChannelSubscriptionItem,
              let cell = tableView.dequeueReusableCell(withIdentifier: "PreferenceCenterCell", for: indexPath) as? PreferenceCenterCell
        else {
            return nil
        }
        
        cell.textLabel?.text = item.display?.title
        cell.detailTextLabel?.text = item.display?.subtitle
        cell.detailTextLabel?.numberOfLines = 0
        
        if let font = style?.preferenceTitleTextFont ?? style?.preferenceTextFont {
            cell.textLabel?.font = font
        }
        
        if let fontColor = style?.preferenceTitleTextColor ?? style?.preferenceTextColor {
            cell.textLabel?.textColor = fontColor
        }
        
        if let font = style?.preferenceSubtitleTextFont ?? style?.preferenceTextFont {
            cell.detailTextLabel?.font = font
        }
        
        if let fontColor = style?.preferenceSubtitleTextColor ?? style?.preferenceTextColor {
            cell.detailTextLabel?.textColor = fontColor
        }
        
        if let backgroundColor = style?.backgroundColor {
            cell.backgroundColor = backgroundColor
        }
            
        if let cellSwitch = cell.accessoryView as? UISwitch {
            if let tintColor = style?.switchTintColor {
                cellSwitch.onTintColor = tintColor
            }
            
            if let thumbTintColor = style?.switchThumbTintColor {
                cellSwitch.thumbTintColor = thumbTintColor
            }
            
            if (activeChannelSubscriptions.contains(item.subscriptionID)) {
                cellSwitch.setOn(true, animated: false)
            } else {
                cellSwitch.setOn(false, animated: false)
            }
        }
        
        cell.callback = { isOn in
            let editor = Airship.channel.editSubscriptionLists()
            if (isOn) {
                self.activeChannelSubscriptions.append(item.subscriptionID)
                editor.subscribe(item.subscriptionID)
            } else {
                self.activeChannelSubscriptions.removeAll(where: { $0 == item.subscriptionID })
                editor.unsubscribe(item.subscriptionID)
            }
            
            editor.apply()
            tableView.reloadData()
        }
        
        return cell
    }
    
    private func bindContactSubscriptionItem(_ item: Item,
                                             tableView: UITableView,
                                             indexPath: IndexPath) -> UITableViewCell? {
        guard let item = item as? ContactSubscriptionItem,
              let cell = tableView.dequeueReusableCell(withIdentifier: "PreferenceCenterCell", for: indexPath) as? PreferenceCenterCell
        else {
            return nil
        }
        
        cell.textLabel?.text = item.display?.title
        cell.detailTextLabel?.text = item.display?.subtitle
        cell.detailTextLabel?.numberOfLines = 0
        
        if let font = style?.preferenceTitleTextFont ?? style?.preferenceTextFont {
            cell.textLabel?.font = font
        }
        
        if let fontColor = style?.preferenceTitleTextColor ?? style?.preferenceTextColor {
            cell.textLabel?.textColor = fontColor
        }
        
        if let font = style?.preferenceSubtitleTextFont ?? style?.preferenceTextFont {
            cell.detailTextLabel?.font = font
        }
        
        if let fontColor = style?.preferenceSubtitleTextColor ?? style?.preferenceTextColor {
            cell.detailTextLabel?.textColor = fontColor
        }
        
        if let backgroundColor = style?.backgroundColor {
            cell.backgroundColor = backgroundColor
        }
            
        if let cellSwitch = cell.accessoryView as? UISwitch {
            if let tintColor = style?.switchTintColor {
                cellSwitch.onTintColor = tintColor
            }
            
            if let thumbTintColor = style?.switchThumbTintColor {
                cellSwitch.thumbTintColor = thumbTintColor
            }
            
            let isSubscribed = isSubscribedContactSubscription(item.subscriptionID)
            cellSwitch.setOn(isSubscribed, animated: false)
        }
        
        cell.callback = { isOn in
            self.applyContactSubscription(item.subscriptionID,
                                          scopes: item.scopes.values,
                                          subscribe: isOn)
            tableView.reloadData()
        }
        return cell
    }

    private func bindContactGroupSubscriptionItem(_ item: Item,
                                                  tableView: UITableView,
                                                  indexPath: IndexPath) -> UITableViewCell?  {
            
        guard let item = item as? ContactSubscriptionGroupItem, let cell = tableView.dequeueReusableCell(withIdentifier: "PreferenceCenterCheckboxCell", for: indexPath) as? PreferenceCenterCheckboxCell else {
            return nil
        }
        
        cell.activeScopes = self.activeContactSubscriptions[item.subscriptionID] ?? []
        cell.callback = { subscribe, scopes in
            self.applyContactSubscription(item.subscriptionID,
                                          scopes: scopes,
                                          subscribe: subscribe)
            tableView.reloadData()
        }
        
        cell.draw(item: item, style: style)

        if (style?.backgroundColor != nil) {
            cell.backgroundColor = style?.backgroundColor
        }

        cell.detailTextLabel?.numberOfLines = 0
        
        return cell
    }
    
    private func isSubscribedContactSubscription(_ subscriptionID: String) -> Bool {
        return activeContactSubscriptions[subscriptionID]?.isEmpty == false
    }
    
    private func applyContactSubscription(_ subscriptionID: String,
                                          scopes: [ChannelScope],
                                          subscribe: Bool) {
        var currentScopes = Set(self.activeContactSubscriptions[subscriptionID] ?? [])
        if (subscribe) {
            currentScopes = currentScopes.union(scopes)
        } else {
            currentScopes = currentScopes.subtracting(scopes)
        }
        self.activeContactSubscriptions[subscriptionID] = Array(currentScopes)
        
        Airship.contact.editSubscriptionLists { editor in
            editor.mutate(subscriptionID, scopes: scopes, subscribe: subscribe)
        }
    }
    
    
    func onConfigLoaded(config: PreferenceCenterConfig,
                        channelLists: [String]?,
                        contactLists: [String : [ChannelScope]]?) {
        self.config = config
        updatePreferenceCenter()
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
        self.activeChannelSubscriptions = channelLists ?? []
        self.activeContactSubscriptions = contactLists ?? [:]
        self.refreshTable()
    }
    
    public func refreshConfig() {
        overlayView.alpha = 1;
        activityIndicator.startAnimating()
        
        self.disposable?.dispose()
        
        var onComplete : ((PreferenceCenterConfig, [String]?, [String : ChannelScopes]?) -> Void)? = { config, channelLists, contactLists in
            self.shouldRefresh = false
            let mappedContactLists = contactLists?.mapValues { $0.values }
            self.onConfigLoaded(config: config, channelLists: channelLists, contactLists: mappedContactLists)
        }
        
        guard let preferenceCenterID = self.preferenceCenterID else {
            return
        }
        
        var cancelled = false
    
        self.disposable = Disposable {
            cancelled = true
            onComplete = nil
        }
        
        PreferenceCenter.shared.config(preferenceCenterID: preferenceCenterID) { [weak self] config in
            guard let config = config else {
                UADispatcher.main.dispatch(after: 30, block: {
                    if (!cancelled) {
                        self?.refreshConfig()
                    }
                })
                return
            }
            
            let containsChannelSubscriptions = config.sections.contains(where: {
                let items = $0.items
                return items.contains(where: {
                    return ($0.itemType == .channelSubscription)
                })
            })
            let containsContactSubscriptions = config.sections.contains(where: {
                let items = $0.items
                return items.contains(where: {
                    return ($0.itemType == .contactSubscription || $0.itemType == .contactSubscriptionGroup)
                })
            })
            
            var subscribedChannelIDs: [String] = []
            var subscribedContactIDs: [String : ChannelScopes] = [:]
            
            let dispatchGroup = DispatchGroup()
            
            if (containsChannelSubscriptions) {
                dispatchGroup.enter()
                Airship.channel.fetchSubscriptionLists() { subscribedIDs, error in
                    guard error == nil, let subscribedIDs = subscribedIDs else {
                        UADispatcher.main.dispatch(after: 30, block: {
                            if (!cancelled) {
                                self?.refreshConfig()
                            }
                        })
                        dispatchGroup.leave()
                        return
                    }
                    subscribedChannelIDs = subscribedIDs
                    dispatchGroup.leave()
                }
            }
            
            if (containsContactSubscriptions) {
                dispatchGroup.enter()
                Airship.contact.fetchSubscriptionLists() { subscribedIDs, error in
                    guard error == nil, let subscribedIDs = subscribedIDs else {
                        UADispatcher.main.dispatch(after: 30, block: {
                            if (!cancelled) {
                                self?.refreshConfig()
                            }
                        })
                        dispatchGroup.leave()
                        return
                    }
                    subscribedContactIDs = subscribedIDs
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                onComplete?(config, subscribedChannelIDs, subscribedContactIDs)
            }
        }
    }
    
    func updatePreferenceCenter() {
        if let config = config {
            self.filteredSections = PreferenceCenterFilteredSection.filterConfig(config)
        } else {
            self.filteredSections = []
        }
        refreshTable()
    }
    
    @objc func refreshTable() {
        tableView.reloadData()

        // Recompute layout so that sizes are correct
        tableView.invalidateIntrinsicContentSize()
        tableView.layoutIfNeeded()
    }
    
    @objc func buttonAction(_ sender: PreferenceAlertButton) {
        let actions = sender.actions as! Dictionary<String, Any>
        if (!actions.isEmpty) {
            for (name,value) in actions {
                ActionRunner.run(name, value: value, situation: .manualInvocation) { result in
                    self.updatePreferenceCenter()
                }
            }
        }
    }
    
    private func fetchImage(url: URL,
                            completion: @escaping (UIImage?) -> Void) {
        
        // Check for a cached image.
        if let cachedImage = imageCache[url] {
            DispatchQueue.main.async {
                completion(cachedImage)
            }
            return
        }
    
        guard imageCompletionHandlers[url] == nil else {
            imageCompletionHandlers[url]?.append(completion)
            return
        }
        
        imageCompletionHandlers[url] = [completion]
    
        DispatchQueue.global().async {
            let image = UIImage().loadImage(url: url, attempts: 3)
            DispatchQueue.main.async {
                self.imageCache[url] = image
                self.imageCompletionHandlers[url]?.forEach { completionHandler in
                    completionHandler(image)
                }
                self.imageCompletionHandlers[url] = nil
            }
        }
    }
    
    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        self.tableView.reloadData()
    }
}

