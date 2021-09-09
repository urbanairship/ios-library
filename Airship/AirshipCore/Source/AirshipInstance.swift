/* Copyright Airship and Contributors */

import Foundation

protocol AirshipInstanceProtocol  {
    var config: RuntimeConfig { get }
    var actionRegistry: ActionRegistry { get }
    var applicationMetrics: ApplicationMetrics { get }
    var locationProvider: UALocationProvider? { get }
    
    #if !os(tvOS)
    var javaScriptCommandDelegate: JavaScriptCommandDelegate? { get set }
    var channelCapture: ChannelCapture { get }
    #endif
    
    var deepLinkDelegate: DeepLinkDelegate? { get set }
    var urlAllowList : URLAllowList { get }
    var localeManager: LocaleManager { get }
    var privacyManager: PrivacyManager { get }
    var components: [Component] { get }
    
    func component(forClassName className: String) -> Component?
    func component<E>(ofType componentType: E.Type) -> E?
}

class AirshipInstance : AirshipInstanceProtocol {
    public let config: RuntimeConfig
    public let actionRegistry: ActionRegistry
    public let applicationMetrics: ApplicationMetrics
    public let locationProvider: UALocationProvider?
    
    #if !os(tvOS)
    public weak var javaScriptCommandDelegate: JavaScriptCommandDelegate?
    public let channelCapture: ChannelCapture
    #endif
    
    public weak var deepLinkDelegate: DeepLinkDelegate?
    public let urlAllowList : URLAllowList
    public let localeManager: LocaleManager
    public let privacyManager: PrivacyManager
    public let components: [Component]
    private let remoteConfigManager: RemoteConfigManager;
    private var componentMap: [String : Component]  = [:]

    init(config: Config) {
        let dataStore = PreferenceDataStore(keyPrefix: config.appKey)
        self.config = RuntimeConfig(config: config, dataStore: dataStore)
        self.privacyManager = PrivacyManager(dataStore: dataStore, defaultEnabledFeatures: config.enabledFeatures)
        self.actionRegistry = ActionRegistry.defaultRegistry()
        self.urlAllowList = URLAllowList.allowListWithConfig(self.config)
        self.applicationMetrics = ApplicationMetrics(dataStore: dataStore, privacyManager: privacyManager)
        self.localeManager = LocaleManager(dataStore: dataStore)
        
        let channel = Channel(dataStore: dataStore,
                                config: self.config,
                                privacyManager: self.privacyManager,
                                localeManager: self.localeManager)
        
        let analytics = Analytics(config: self.config,
                                    dataStore: dataStore,
                                    channel: channel,
                                    localeManager: localeManager,
                                    privacyManager: privacyManager)
        
        let push = Push(config: self.config,
                          dataStore: dataStore,
                          channel: channel,
                          analytics: analytics,
                          privacyManager: self.privacyManager)
        
        let contact = Contact(dataStore: dataStore,
                                config: self.config,
                                channel: channel,
                                privacyManager: self.privacyManager)
        
        let namedUser = NamedUser(dataStore: dataStore, contact: contact)
        
        let remoteDataManager = RemoteDataManager(config: self.config,
                                                    dataStore: dataStore,
                                                    localeManager: self.localeManager,
                                                    privacyManager: self.privacyManager)
        
        self.remoteConfigManager = RemoteConfigManager(remoteDataManager: remoteDataManager,
                                                        privacyManager: self.privacyManager)
        
        
        #if !os(tvOS)
        self.channelCapture = ChannelCapture(config: self.config,
                                             dataStore: dataStore,
                                             channel: channel)
        #endif
        
        let moduleLoader = ModuleLoader(config: self.config,
                                        dataStore: dataStore,
                                        channel: channel,
                                        contact: contact,
                                        push: push,
                                        remoteData: remoteDataManager,
                                        analytics: analytics,
                                        privacyManager: self.privacyManager)
        
        var components: [Component] = [contact, channel, analytics, namedUser, remoteDataManager, push]
        components.append(contentsOf: moduleLoader.components)
        
        self.locationProvider = components.compactMap {
            return $0 as? UALocationProvider
        }.first
            
        self.components = components
            
        moduleLoader.actionPlists.forEach {
            self.actionRegistry.registerActions($0)
        }
    }
    
    
    public func component(forClassName className: String) -> Component? {
        let key = "Class:\(className)"
        if componentMap[key] == nil {
            self.componentMap[key] = self.components.first { NSStringFromClass(type(of: $0)) == className }
        }

        return componentMap[key]
    }
    
    public func component<E>(ofType componentType: E.Type) -> E? {
        let key = "Type:\(componentType)"
        if componentMap[key] == nil {
            self.componentMap[key] = self.components.first { ($0 as? E) != nil }
        }

        return componentMap[key] as? E
    }
}
