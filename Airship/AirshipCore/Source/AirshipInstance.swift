/* Copyright Airship and Contributors */

import Foundation

protocol AirshipInstanceProtocol {
    var config: RuntimeConfig { get }
    var preferenceDataStore: PreferenceDataStore { get }
    var actionRegistry: ActionRegistry { get }
    var permissionsManager: AirshipPermissionsManager { get }

    #if !os(tvOS) && !os(watchOS)
    var javaScriptCommandDelegate: JavaScriptCommandDelegate? { get set }
    var channelCapture: ChannelCapture { get }
    #endif

    var deepLinkDelegate: DeepLinkDelegate? { get set }
    var urlAllowList: URLAllowListProtocol { get }
    var localeManager: AirshipLocaleManager { get }
    var privacyManager: AirshipPrivacyManager { get }
    var components: [AirshipComponent] { get }

    func component<E>(ofType componentType: E.Type) -> E?

    @MainActor
    func airshipReady()
}

final class AirshipInstance: AirshipInstanceProtocol {
    public let config: RuntimeConfig
    public let preferenceDataStore: PreferenceDataStore

    public let actionRegistry: ActionRegistry
    public let permissionsManager: AirshipPermissionsManager

    #if !os(tvOS) && !os(watchOS)

    public weak var javaScriptCommandDelegate: JavaScriptCommandDelegate?
    public let channelCapture: ChannelCapture
    #endif

    public weak var deepLinkDelegate: DeepLinkDelegate?
    public let urlAllowList: URLAllowListProtocol
    public let localeManager: AirshipLocaleManager
    public let privacyManager: AirshipPrivacyManager
    public let components: [AirshipComponent]
    private let remoteConfigManager: RemoteConfigManager
    private let experimentManager: ExperimentDataProvider
    private var componentMap: [String: AirshipComponent] = [:]
    private var lock = AirshipLock()

    @MainActor
    init(config: AirshipConfig) {
        let requestSession = DefaultAirshipRequestSession(
            appKey: config.appKey,
            appSecret: config.appSecret
        )
        let dataStore = PreferenceDataStore(appKey: config.appKey)
        self.preferenceDataStore = dataStore
        self.permissionsManager = AirshipPermissionsManager()
        self.config = RuntimeConfig(config: config, dataStore: dataStore, requestSession: requestSession)
        
        self.privacyManager = AirshipPrivacyManager(
            dataStore: dataStore,
            config: self.config,
            defaultEnabledFeatures: config.enabledFeatures
        )

        self.actionRegistry = ActionRegistry()
        self.urlAllowList = URLAllowList.allowListWithConfig(self.config)
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
            remoteData: remoteData
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
            cache: CoreDataAirshipCache(appKey: self.config.appKey)
        )

        var components: [AirshipComponent] = [
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
