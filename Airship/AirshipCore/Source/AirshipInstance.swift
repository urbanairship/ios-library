/* Copyright Airship and Contributors */

import Foundation

protocol AirshipInstanceProtocol: Sendable {
    var config: RuntimeConfig { get }
    var preferenceDataStore: PreferenceDataStore { get }
    var actionRegistry: ActionRegistry { get }
    var permissionsManager: AirshipPermissionsManager { get }

    #if !os(tvOS) && !os(watchOS)
    var javaScriptCommandDelegate: (any JavaScriptCommandDelegate)? { get set }
    var channelCapture: ChannelCapture { get }
    #endif

    var deepLinkDelegate: (any DeepLinkDelegate)? { get set }
    var urlAllowList: any URLAllowListProtocol { get }
    var localeManager: AirshipLocaleManager { get }
    var privacyManager: AirshipPrivacyManager { get }
    var components: [any AirshipComponent] { get }

    func component<E>(ofType componentType: E.Type) -> E?

    @MainActor
    func airshipReady()
}

final class AirshipInstance: AirshipInstanceProtocol, @unchecked Sendable {
    public let config: RuntimeConfig
    public let preferenceDataStore: PreferenceDataStore
    
    public let actionRegistry: ActionRegistry
    public let permissionsManager: AirshipPermissionsManager
    
#if !os(tvOS) && !os(watchOS)
    
    private let _jsDelegateHolder = AirshipAtomicValue<(any JavaScriptCommandDelegate)?>(nil)
    public var javaScriptCommandDelegate: (any JavaScriptCommandDelegate)? {
        get { return _jsDelegateHolder.value }
        set { _jsDelegateHolder.value = newValue }
    }
    public let channelCapture: ChannelCapture
#endif
    
    private let _deeplinkDelegateHolder = AirshipAtomicValue<(any DeepLinkDelegate)?>(nil)
    public var deepLinkDelegate: (any DeepLinkDelegate)? {
        get { _deeplinkDelegateHolder.value }
        set { _deeplinkDelegateHolder.value = newValue }
    }
    public let urlAllowList: any URLAllowListProtocol
    public let localeManager: AirshipLocaleManager
    public let privacyManager: AirshipPrivacyManager
    public let components: [any AirshipComponent]
    private let remoteConfigManager: RemoteConfigManager
    private let experimentManager: any ExperimentDataProvider
    private var componentMap: [String: any AirshipComponent] = [:] //it's accessed with the lock below
    private let lock = AirshipLock()
    
    @MainActor
    init(airshipConfig: AirshipConfig, appCredentials: AirshipAppCredentials) {
        let requestSession = DefaultAirshipRequestSession(
            appKey: appCredentials.appKey,
            appSecret: appCredentials.appSecret
        )

        let dataStore = PreferenceDataStore(appKey: appCredentials.appKey)
        self.preferenceDataStore = dataStore
        self.permissionsManager = AirshipPermissionsManager()
        self.config = RuntimeConfig(
            airshipConfig: airshipConfig,
            appCredentials: appCredentials,
            dataStore: dataStore,
            requestSession: requestSession
        )

        self.privacyManager = AirshipPrivacyManager(
            dataStore: dataStore,
            config: self.config,
            defaultEnabledFeatures: airshipConfig.enabledFeatures
        )
        
        self.actionRegistry = ActionRegistry()
        self.urlAllowList = URLAllowList(airshipConfig: airshipConfig)
        self.localeManager = AirshipLocaleManager(
            dataStore: dataStore,
            config: self.config
        )
        
#if !os(watchOS)
        let apnsRegistrar = UIApplicationAPNSRegistrar()
#else
        let apnsRegistrar = WKExtensionAPNSRegistrar()
#endif
        
        let audienceOverridesProvider = DefaultAudienceOverridesProvider()
        
        
        let channel = AirshipChannel(
            dataStore: dataStore,
            config: self.config,
            privacyManager: self.privacyManager,
            localeManager: self.localeManager,
            audienceOverridesProvider: audienceOverridesProvider
        )
        
        requestSession.channelAuthTokenProvider = ChannelAuthTokenProvider(
            channel: channel,
            runtimeConfig: self.config
        )

        let cache = CoreDataAirshipCache(appKey: appCredentials.appKey)
        let audienceChecker = DefaultDeviceAudienceChecker()

        
        let analytics = AirshipAnalytics(
            config: self.config,
            dataStore: dataStore,
            channel: channel,
            localeManager: localeManager,
            privacyManager: privacyManager,
            permissionsManager: permissionsManager
        )
        
        let push = AirshipPush(
            config: self.config,
            dataStore: dataStore,
            channel: channel,
            analytics: analytics,
            privacyManager: self.privacyManager,
            permissionsManager: self.permissionsManager,
            apnsRegistrar: apnsRegistrar,
            badger: Badger.shared
        )
        
        let contact = AirshipContact(
            dataStore: dataStore,
            config: self.config,
            channel: channel,
            privacyManager: self.privacyManager,
            audienceOverridesProvider: audienceOverridesProvider,
            localeManager: self.localeManager
        )
        requestSession.contactAuthTokenProvider = contact.authTokenProvider
        
        let remoteData = RemoteData(
            config: self.config,
            dataStore: dataStore,
            localeManager: self.localeManager,
            privacyManager: self.privacyManager,
            contact: contact
        )
        
        self.experimentManager = ExperimentManager(
            dataStore: dataStore,
            remoteData: remoteData,
            audienceChecker: audienceChecker
        )
        
        let meteredUsage = AirshipMeteredUsage(
            config: self.config,
            dataStore: dataStore,
            channel: channel,
            contact: contact,
            privacyManager: privacyManager
        )
        
#if !os(tvOS) && !os(watchOS)
        self.channelCapture = ChannelCapture(
            config: self.config,
            channel: channel
        )
#endif
        
        let deferredResolver = AirshipDeferredResolver(
            config: self.config,
            audienceOverrides: audienceOverridesProvider
        )
        
        let moduleLoader = ModuleLoader(
            config: self.config,
            dataStore: dataStore,
            channel: channel,
            contact: contact,
            push: push,
            remoteData: remoteData,
            analytics: analytics,
            privacyManager: self.privacyManager,
            permissionsManager: self.permissionsManager,
            audienceOverrides: audienceOverridesProvider,
            experimentsManager: experimentManager,
            meteredUsage: meteredUsage,
            deferredResolver: deferredResolver,
            cache: cache,
            audienceChecker: audienceChecker
        )
        
        var components: [any AirshipComponent] = [
            contact, channel, analytics, remoteData, push
        ]
        components.append(contentsOf: moduleLoader.components)
        
        self.components = components
        
        self.remoteConfigManager = RemoteConfigManager(
            config: self.config,
            remoteData: remoteData,
            privacyManager: self.privacyManager
        )
        
        self.actionRegistry.registerActions(
            actionsManifests: moduleLoader.actionManifests + [DefaultActionsManifest()]
        )
    }
    
    public func component<E>(ofType componentType: E.Type) -> E? {
        var component: E?
        lock.sync {
            let key = "Type:\(componentType)"
            if componentMap[key] == nil {
                self.componentMap[key] = self.components.first {
                    ($0 as? E) != nil
                }
            }
            
            component = componentMap[key] as? E
        }
        return component
    }
    
    @MainActor
    func airshipReady() {
        self.components.forEach { $0.airshipReady() }
        self.remoteConfigManager.airshipReady()
    }
}
