/* Copyright Airship and Contributors */

import Foundation

/// Allowed SDK extension types.
/// - Note: For internal use only. :nodoc:
@objc(UASDKExtension)
public enum SDKExtension : Int {
    /// The Cordova SDK extension.
    case cordova = 0
    /// The Xamarin SDK extension.
    case xamarin = 1
    /// The Unity SDK extension.
    case unity = 2
    /// The Flutter SDK extension.
    case flutter = 3
    /// The React Native SDK extension.
    case reactNative = 4
    /// The Titanium SDK extension.
    case titanium = 5
}

/// The Analytics object provides an interface to the Airship Analytics API.
@objc(UAAnalytics)
public class Analytics: NSObject, Component, AnalyticsProtocol, EventManagerDelegate {
    
    /**
     * Analytics supplier, for testing purposes. :nodoc:
     */
    @objc
    public static let supplier: () -> AnalyticsProtocol = {
        return Airship.requireComponent(ofType: AnalyticsProtocol.self)
    }
    
    /// The shared Analytics instance.
    @objc
    public static var shared: Analytics {
        return Airship.analytics
    }
    
    private static let associatedIdentifiers = "UAAssociatedIdentifiers"
    private static let missingSendID = "MISSING_SEND_ID"
    private static let pushMetadata = "com.urbanairship.metadata"

    /// Screen key for ScreenTracked notification. :nodoc:
    @objc
    public static let screenKey = "screen"

    /// Event key for customEventAdded and regionEventAdded notifications.. :nodoc:
    @objc
    public static let eventKey = "event"

    /// Custom event added notification. :nodoc:
    @objc
    public static let customEventAdded = NSNotification.Name("UACustomEventAdded")

    /// Region event added notification. :nodoc:
    @objc
    public static let regionEventAdded = NSNotification.Name("UARegionEventAdded")

    /// Screen tracked notification,. :nodoc:
    @objc
    public static let screenTracked = NSNotification.Name("UAScreenTracked")

    private var config: RuntimeConfig
    private var dataStore: PreferenceDataStore
    private var channel: ChannelProtocol
    private var eventManager: EventManagerProtocol
    private var privacyManager: PrivacyManager
    private var notificationCenter: NotificationCenter
    private var date: AirshipDate
    private var dispatcher: UADispatcher
    private var sdkExtensions: [String]
    private var headerBlocks: [(() -> [String : String]?)]
    private var localeManager: LocaleManagerProtocol
    private var appStateTracker: AppStateTrackerProtocol
    private var handledFirstForegroundTransition = false
    private var permissionsManager: PermissionsManager

    // Screen tracking state
    private var currentScreen: String?
    private var previousScreen: String?
    private var startTime: TimeInterval = 0.0

    private let lock = Lock()
    private var initialized = false
    private var isAirshipReady = false

    private var isAnalyticsEnabled: Bool {
        get {
            return self.isComponentEnabled && self.config.isAnalyticsEnabled && self.privacyManager.isEnabled(.analytics)
        }
    }

    /// The conversion send ID. :nodoc:
    @objc
    public var conversionSendID: String?

    /// The conversion push metadata. :nodoc:
    @objc
    public var conversionPushMetadata: String?

    /// The current session ID.
    @objc
    public private(set) var sessionID: String?

    /// Optional event consumer.
    ///
    /// - Note: AirshipDebug uses the event consumer to capture events. Setting the event
    /// consumer for other purposes will result in an interruption to AirshipDebug's event stream.
    ///
    /// For internal use only. :nodoc:
    @objc
    public var eventConsumer: AnalyticsEventConsumerProtocol?

    private let disableHelper: ComponentDisableHelper
        
    // NOTE: For internal use only. :nodoc:
    public var isComponentEnabled: Bool {
        get {
            return disableHelper.enabled
        }
        set {
            disableHelper.enabled = newValue
        }
    }

    /// Factory method to create an analytics instance.
    /// - Note: For internal use only. :nodoc:
    /// - Parameters:
    ///   - config: The runtime config.
    ///   - dataStore: The shared preference data store.
    ///   - channel: The channel instance.
    ///   - localeManager: A UALocaleManager.
    ///   - privacyManager: A PrivacyManager.
    ///   - permissionsManager: The permissions manager.
    /// - Returns: A new analytics instance.
    @objc
    public convenience init(
        config: RuntimeConfig,
        dataStore: PreferenceDataStore,
        channel: ChannelProtocol,
        localeManager: LocaleManagerProtocol,
        privacyManager: PrivacyManager,
        permissionsManager: PermissionsManager
    ) {
        self.init(config: config,
                  dataStore: dataStore,
                  channel: channel,
                  eventManager: EventManager(config: config, dataStore: dataStore, channel: channel),
                  notificationCenter: NotificationCenter.default,
                  date: AirshipDate(),
                  dispatcher: UADispatcher.main,
                  localeManager: localeManager,
                  appStateTracker: AppStateTracker.shared,
                  privacyManager: privacyManager,
                  permissionsManager: permissionsManager)
    }

    /// Factory method to create an analytics instance. Used for testing.
    /// - Note: For internal use only. :nodoc:
    /// - Parameters:
    ///   - config: The runtime config.
    ///   - dataStore: The shared preference data store.
    ///   - channel: The channel instance.
    ///   - eventManager: The event manager.
    ///   - notificationCenter: The notification center.
    ///   - date: A DateUtils instance.
    ///   - dispatcher: The dispatcher.
    ///   - localeManager: The locale manager.
    ///   - appStateTracker: The app state tracker.
    ///   - privacyManager: The privacy manager.
    ///   - permissionsManager: The permissions manager.
    /// - Returns: A new analytics instance.
    @objc
    public init(
        config: RuntimeConfig,
        dataStore: PreferenceDataStore,
        channel: ChannelProtocol,
        eventManager: EventManagerProtocol,
        notificationCenter: NotificationCenter,
        date: AirshipDate,
        dispatcher: UADispatcher,
        localeManager: LocaleManagerProtocol,
        appStateTracker: AppStateTrackerProtocol,
        privacyManager: PrivacyManager,
        permissionsManager: PermissionsManager
    ) {
        self.config = config
        self.dataStore = dataStore
        self.channel = channel
        self.eventManager = eventManager
        self.notificationCenter = notificationCenter
        self.date = date
        self.dispatcher = dispatcher
        self.localeManager = localeManager
        self.privacyManager = privacyManager
        self.appStateTracker = appStateTracker
        self.permissionsManager = permissionsManager

        self.sdkExtensions = []
        self.headerBlocks = []

        self.disableHelper = ComponentDisableHelper(dataStore: dataStore, className: "UAAnalytics")

        super.init()
        
        self.disableHelper.onChange = { [weak self] in
            self?.onComponentEnableChange()
        }
        
        self.eventManager.delegate = self

        updateEventManagerUploadsEnabled()
        startSession()

        self.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidTransitionToForeground),
            name: AppStateTracker.didTransitionToForeground,
            object: nil)

        self.notificationCenter.addObserver(
            self,
            selector: #selector(applicationWillEnterForeground),
            name: AppStateTracker.willEnterForegroundNotification,
            object: nil)

        self.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: AppStateTracker.didEnterBackgroundNotification,
            object: nil)

        self.notificationCenter.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: AppStateTracker.willTerminateNotification,
            object: nil)

        self.notificationCenter.addObserver(
            self,
            selector: #selector(onEnabledFeaturesChanged),
            name: PrivacyManager.changeEvent,
            object: nil)
    }

    // MARK: -
    // MARK: Application State
    @objc
    private func applicationDidTransitionToForeground() {
        AirshipLogger.debug("Application transitioned to foreground.")

        // If the app is transitioning to foreground for the first time, ensure an app init event
        guard handledFirstForegroundTransition else {
            handledFirstForegroundTransition = true
            ensureInit()
            return
        }
        
        // Otherwise start a new session and emit a foreground event.
        startSession()

        // Add app_foreground event
        self.addEvent(AppForegroundEvent())
    }

    @objc
    private func applicationWillEnterForeground() {
        AirshipLogger.debug("Application will enter foreground.")

        // Start tracking previous screen before backgrounding began
        trackScreen(previousScreen)
    }

    @objc
    private func applicationDidEnterBackground() {
        AirshipLogger.debug("Application did enter background.")

        stopTrackingScreen()

        // Ensure an app init event
        ensureInit()
        
        // Add app_background event
        self.addEvent(AppBackgroundEvent())

        startSession()
        conversionSendID = nil
        conversionPushMetadata = nil
    }

    @objc
    private func applicationWillTerminate() {
        AirshipLogger.debug("Application is terminating.")
        stopTrackingScreen()
    }

    // MARK: -
    // MARK: Analytics Headers

    /// :nodoc:
    @objc(addAnalyticsHeadersBlock:)
    public func add(_ headerBlock: @escaping () -> [String : String]?) {
        self.headerBlocks.append(headerBlock)
    }

    /// :nodoc:
    @objc
    public func analyticsHeaders(completionHandler: @escaping ([String : String]) -> Void) {
        var headers: [String : String] = [:]

        // Device info
        #if !os(watchOS)
        headers["X-UA-Device-Family"] = UIDevice.current.systemName
        headers["X-UA-OS-Version"] = UIDevice.current.systemVersion
        #else
        headers["X-UA-Device-Family"] = WKInterfaceDevice.current().systemName
        headers["X-UA-OS-Version"] = WKInterfaceDevice.current().systemVersion
        #endif
        
        headers["X-UA-Device-Model"] = Utils.deviceModelName()

        // App info
        if let infoDictionary  = Bundle.main.infoDictionary {
            headers["X-UA-Package-Name"] = infoDictionary[kCFBundleIdentifierKey as String] as? String
        }

        headers["X-UA-Package-Version"] = Utils.bundleShortVersionString() ?? ""

        // Time zone
        let currentLocale = self.localeManager.currentLocale
        headers["X-UA-Timezone"] = NSTimeZone.default.identifier
        headers["X-UA-Locale-Language"] = currentLocale.languageCode
        headers["X-UA-Locale-Country"] = currentLocale.regionCode
        headers["X-UA-Locale-Variant"] = currentLocale.variantCode

        // Airship identifiers
        headers["X-UA-Channel-ID"] = self.channel.identifier
        headers["X-UA-App-Key"] = self.config.appKey

        // SDK Version
        headers["X-UA-Lib-Version"] = AirshipVersion.get()

        // SDK Extensions
        if self.sdkExtensions.count > 0 {
            headers["X-UA-Frameworks"] = self.sdkExtensions.joined(separator: ", ")
        }

        // Header extenders
        for block in self.headerBlocks {
            if let result = block() {
                headers.merge(result, uniquingKeysWith: { (current, _) in current })
            }
        }

        let group = DispatchGroup()
        group.enter()

        self.permissionsManager.configuredPermissions.forEach { permission in
            group.enter()
            self.permissionsManager.checkPermissionStatus(permission) { status in
                headers["X-UA-Permission-\(permission.stringValue)"] = status.stringValue
                group.leave()
            }
        }

        group.leave()
        group.notify(queue: DispatchQueue.global()) {
            completionHandler(headers);
        }
    }

    // MARK: -
    // MARK: Analytics Core Methods

    /// Triggers an analytics event.
    /// - Parameter event: The event to be triggered
    @objc
    public func addEvent(_ event: Event) {
        guard event.isValid?() != false else {
            AirshipLogger.error("Dropping invalid event: \(event)")
            return
        }

        guard let sessionID = self.sessionID else {
            AirshipLogger.error("Missing session ID")
            return
        }

        let date = Date();
        let identifier = NSUUID().uuidString

        self.dispatcher.dispatchAsync { [weak self] in
            guard let self = self else {
                return
            }

            guard self.isAnalyticsEnabled else {
                AirshipLogger.trace("Analytics disabled, ignoring event: \(event.eventType)")
                return
            }

            AirshipLogger.debug("Adding \(event.eventType) event \(identifier)")
            self.eventManager.add(event, eventID: identifier, eventDate: date, sessionID: sessionID)
            AirshipLogger.trace("Event added: \(event)")

            if let eventConsumer = self.eventConsumer {
                eventConsumer.eventAdded(event: event, eventID: identifier, eventDate: date)
            }

            if let customEvent = event as? CustomEvent {
                self.notificationCenter.post(name: Analytics.customEventAdded, object: self, userInfo: [Analytics.eventKey : customEvent])
            }

            if let regionEvent = event as? RegionEvent {
                self.notificationCenter.post(name: Analytics.regionEventAdded, object: self, userInfo: [Analytics.eventKey : regionEvent])
            }
        }
    }

    /// Associates identifiers with the device. This call will add a special event
    /// that will be batched and sent up with our other analytics events. Previous
    /// associated identifiers will be replaced.
    ///
    /// For internal use only. :nodoc:
    ///
    /// - Parameter associatedIdentifiers: The associated identifiers.
    @objc
    public func associateDeviceIdentifiers(_ associatedIdentifiers: AssociatedIdentifiers) {
        guard self.isAnalyticsEnabled else {
            AirshipLogger.warn("Unable to associate identifiers \(associatedIdentifiers.allIDs) when analytics is disabled")
            return
        }

        if let previous = self.dataStore.object(forKey: Analytics.associatedIdentifiers) as? [String : String] {
            if previous == associatedIdentifiers.allIDs {
                AirshipLogger.info("Skipping analytics event addition for duplicate associated identifiers.")
                return
            }
        }

        self.dataStore.setObject(associatedIdentifiers.allIDs, forKey: Analytics.associatedIdentifiers)

        if let event = AssociateIdentifiersEvent(identifiers: associatedIdentifiers) {
            self.addEvent(event)
        }
    }

    /// The device's current associated identifiers.
    /// - Returns: The device's current associated identifiers.
    @objc
    public func currentAssociatedDeviceIdentifiers() -> AssociatedIdentifiers {
        let storedIDs = self.dataStore.object(forKey: Analytics.associatedIdentifiers) as? [String : String]
        return AssociatedIdentifiers(dictionary: storedIDs != nil ? storedIDs : [:])
    }

    /// Initiates screen tracking for a specific app screen, must be called once per tracked screen.
    /// - Parameter screen: The screen's identifier.
    @objc
    public func trackScreen(_ screen: String?) {
        self.dispatcher.dispatchAsyncIfNecessary {
            // Prevent duplicate calls to track same screen
            guard screen != self.currentScreen else {
                return;
            }

            self.notificationCenter.post(name: Analytics.screenTracked, object: self, userInfo: screen == nil ? [:] : [Analytics.screenKey : screen!])

            // If there's a screen currently being tracked set it's stop time and add it to analytics
            if let currentScreen = self.currentScreen {
                guard let ste = ScreenTrackingEvent(screen: currentScreen, previousScreen: self.previousScreen, startTime: self.startTime, stopTime: self.date.now.timeIntervalSince1970) else {
                    AirshipLogger.error("Unable to create screen tracking event")
                    return
                }

                // Set previous screen to last tracked screen
                self.previousScreen = self.currentScreen

                // Add screen tracking event to next analytics batch
                self.addEvent(ste)
            }

            self.currentScreen = screen
            self.startTime = self.date.now.timeIntervalSince1970
        }
    }

    /// Schedules an event upload if one is not already scheduled.
    @objc
    public func scheduleUpload() {
        self.eventManager.scheduleUpload()
    }

    /// Registers an SDK extension with the analytics module.
    /// For internal use only. :nodoc:
    ///
    ///  - Parameters:
    ///   - ext: The SDK extension.
    ///   - version: The version.
    @objc
    public func registerSDKExtension(_ ext: SDKExtension, version: String) {
        let sanitizedVersion = version.replacingOccurrences(of: ",", with: "")
        let name = self.nameForSDKExtension(ext)
        self.sdkExtensions.append("\(name):\(sanitizedVersion)")
    }

    /// Called to notify analytics the app was launched from a push notification.
    /// For internal use only. :nodoc:
    /// - Parameter notification: The push notification.
    @objc
    public func launched(fromNotification notification: [AnyHashable : Any]) {
        if Utils.isAlertingPush(notification) {
            let sendID = notification["_"] as? String
            self.conversionSendID = sendID != nil ? sendID : Analytics.missingSendID
            self.conversionPushMetadata = notification[Analytics.pushMetadata] as? String
            self.ensureInit()
        } else {
            self.conversionSendID = nil
            self.conversionPushMetadata = nil
        }
    }

    private func onComponentEnableChange() {
        self.updateEventManagerUploadsEnabled()
    }

    @objc
    private func onEnabledFeaturesChanged() {
        self.updateEventManagerUploadsEnabled();
    }

    private func nameForSDKExtension(_ ext: SDKExtension) -> String {
        switch (ext) {
        case .cordova:
            return "cordova"
        case .xamarin:
            return "xamarin"
        case .unity:
            return "unity"
        case .flutter:
            return "flutter"
        case .reactNative:
            return "react-native"
        case .titanium:
            return "titanium"
        default:
            return ""
        }
    }

    private func stopTrackingScreen() {
        self.trackScreen(nil)
    }

    private func updateEventManagerUploadsEnabled() {
        if self.isAnalyticsEnabled {
            self.eventManager.uploadsEnabled = true;
            self.eventManager.scheduleUpload()
        } else {
            self.eventManager.uploadsEnabled = false
            self.eventManager.deleteAllEvents()
            self.dataStore.setValue(nil, forKey: Analytics.associatedIdentifiers)
        }
    }

    private func startSession() {
        self.sessionID = NSUUID().uuidString
    }
    
    /// needed to ensure AppInit event gets added
    /// since App Clips get launched via Push Notification delegate
    private func ensureInit() {
        lock.sync {
            if (!self.initialized && self.isAirshipReady) {
                self.addEvent(AppInitEvent())
                self.initialized = true
            }
        }
    }
    
    public func airshipReady() {
        self.isAirshipReady = true
        
        // If analytics is initialized in the background state, we are responding to a
        // content-available push. If it's initialized in the foreground state takeOff
        // was probably called late. We should ensure an init event in either case.
        if self.appStateTracker.state != .inactive {
            ensureInit()
        }
    }
}

extension Analytics : InternalAnalyticsProtocol {
    func onDeviceRegistration() {
        if (self.isAirshipReady) {
            addEvent(DeviceRegistrationEvent())
        }
    }
    
    @available(tvOS, unavailable)
    func onNotificationResponse(response: UNNotificationResponse, action: UNNotificationAction?) {
        let userInfo = response.notification.request.content.userInfo

        if (response.actionIdentifier == UNNotificationDefaultActionIdentifier) {
            self.launched(fromNotification: userInfo)
        } else if let action = action {
            let categoryID = response.notification.request.content.categoryIdentifier
            let responseText = (response as? UNTextInputNotificationResponse)?.userText
            
            if (action.options.contains(.foreground) == true) {
                self.launched(fromNotification: userInfo)
            }
            
            let event = InteractiveNotificationEvent(action: action,
                                                       category: categoryID,
                                                       notification: userInfo,
                                                       responseText: responseText)
            addEvent(event)
        }
    }
}
