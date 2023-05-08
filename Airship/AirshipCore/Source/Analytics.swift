/* Copyright Airship and Contributors */

import Combine
import Foundation

/// The Analytics object provides an interface to the Airship Analytics API.
@objc(UAAnalytics)
public final class AirshipAnalytics: NSObject, Component, AnalyticsProtocol, @unchecked Sendable {

    /// The shared Analytics instance.
    @objc
    public static var shared: AirshipAnalytics {
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
    public static let customEventAdded = NSNotification.Name(
        "UACustomEventAdded"
    )

    /// Region event added notification. :nodoc:
    @objc
    public static let regionEventAdded = NSNotification.Name(
        "UARegionEventAdded"
    )

    /// Screen tracked notification,. :nodoc:
    @objc
    public static let screenTracked = NSNotification.Name("UAScreenTracked")

    private let config: RuntimeConfig
    private let dataStore: PreferenceDataStore
    private let channel: AirshipChannelProtocol
    private let privacyManager: AirshipPrivacyManager
    private let notificationCenter: AirshipNotificationCenter
    private let date: AirshipDateProtocol
    private let eventManager: EventManagerProtocol
    private let localeManager: AirshipLocaleManagerProtocol
    private let appStateTracker: AppStateTrackerProtocol
    private let permissionsManager: AirshipPermissionsManager
    private let disableHelper: ComponentDisableHelper
    private let lifeCycleEventFactory: LifeCycleEventFactoryProtocol
    private let serialQueue: AsyncSerialQueue = AsyncSerialQueue()

    private let sdkExtensions: Atomic<[String]> = Atomic([])

    // Screen tracking state
    private var currentScreen: String?
    private var previousScreen: String?
    private var screenStartDate: Date?

    private var initialized = false
    private var isAirshipReady = false
    private var handledFirstForegroundTransition = false
    private let lock = AirshipLock()

    private var _conversionSendID : String? = nil
       
    /// The conversion send ID. :nodoc:
   @objc
   public var conversionSendID: String? {
       get {
           var result: String? = nil
           lock.sync {
               result = self._conversionSendID
           }
           return result
       }
       set {
           lock.sync {
               self._conversionSendID = newValue
           }
       }
    }

   private var _conversionPushMetadata : String? = nil
   
   /// The conversion push metadata. :nodoc:
   @objc
   public var conversionPushMetadata: String? {
       get {
           var result: String? = nil
           lock.sync {
               result = self._conversionPushMetadata
           }
           return result
       }
       set {
           lock.sync {
               self._conversionPushMetadata = newValue
           }
       }
   }

    /// The current session ID.
    @objc
    public private(set) var sessionID: String?

    private let eventSubject = PassthroughSubject<AirshipEventData, Never>()

    /// Airship event publisher
    public var eventPublisher: AnyPublisher<AirshipEventData, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    // NOTE: For internal use only. :nodoc:
    public var isComponentEnabled: Bool {
        get {
            return disableHelper.enabled
        }
        set {
            disableHelper.enabled = newValue
        }
    }

    private var isAnalyticsEnabled: Bool {
        return self.privacyManager.isEnabled(.analytics) &&
        self.config.isAnalyticsEnabled &&
        self.isComponentEnabled
    }

    convenience init(
        config: RuntimeConfig,
        dataStore: PreferenceDataStore,
        channel: AirshipChannelProtocol,
        localeManager: AirshipLocaleManagerProtocol,
        privacyManager: AirshipPrivacyManager,
        permissionsManager: AirshipPermissionsManager
    ) {
        self.init(
            config: config,
            dataStore: dataStore,
            channel: channel,
            localeManager: localeManager,
            privacyManager: privacyManager,
            permissionsManager: permissionsManager,
            eventManager: EventManager(config: config, dataStore: dataStore)
        )
    }

    init(
        config: RuntimeConfig,
        dataStore: PreferenceDataStore,
        channel: AirshipChannelProtocol,
        notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter.shared,
        date: AirshipDateProtocol = AirshipDate.shared,
        localeManager: AirshipLocaleManagerProtocol,
        appStateTracker: AppStateTrackerProtocol = AppStateTracker.shared,
        privacyManager: AirshipPrivacyManager,
        permissionsManager: AirshipPermissionsManager,
        eventManager: EventManagerProtocol,
        lifeCycleEventFactory: LifeCycleEventFactoryProtocol = LifeCylceEventFactory()
    ) {
        self.config = config
        self.dataStore = dataStore
        self.channel = channel
        self.notificationCenter = notificationCenter
        self.date = date
        self.localeManager = localeManager
        self.privacyManager = privacyManager
        self.appStateTracker = appStateTracker
        self.permissionsManager = permissionsManager
        self.eventManager = eventManager
        self.lifeCycleEventFactory = lifeCycleEventFactory

        self.disableHelper = ComponentDisableHelper(
            dataStore: dataStore,
            className: "UAAnalytics"
        )

        super.init()

        self.disableHelper.onChange = { [weak self] in
            self?.updateEnablement()
        }

        self.eventManager.addHeaderProvider {
            await self.makeHeaders()
        }

        startSession()

        self.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidTransitionToForeground),
            name: AppStateTracker.didTransitionToForeground,
            object: nil
        )

        self.notificationCenter.addObserver(
            self,
            selector: #selector(applicationWillEnterForeground),
            name: AppStateTracker.willEnterForegroundNotification,
            object: nil
        )

        self.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: AppStateTracker.didEnterBackgroundNotification,
            object: nil
        )

        self.notificationCenter.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: AppStateTracker.willTerminateNotification,
            object: nil
        )

        self.notificationCenter.addObserver(
            self,
            selector: #selector(updateEnablement),
            name: AirshipPrivacyManager.changeEvent,
            object: nil
        )

        self.notificationCenter.addObserver(
            self,
            selector: #selector(updateEnablement),
            name: AirshipChannel.channelCreatedEvent,
            object: nil
        )
    }

    // MARK: -
    // MARK: Application State
    @objc
    @MainActor
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
        self.addLifeCycleEvent(.foreground)
    }

    @objc
    private func applicationWillEnterForeground() {
        AirshipLogger.debug("Application will enter foreground.")

        // Start tracking previous screen before backgrounding began
        trackScreen(previousScreen)
    }

    @objc
    @MainActor
    private func applicationDidEnterBackground() {
        AirshipLogger.debug("Application did enter background.")

        self.trackScreen(nil)

        // Ensure an app init event
        ensureInit()

        // Add app_background event
        self.addLifeCycleEvent(.background)

        startSession()
        conversionSendID = nil
        conversionPushMetadata = nil
    }

    @objc
    private func applicationWillTerminate() {
        AirshipLogger.debug("Application is terminating.")
        self.trackScreen(nil)
    }


    // MARK: -
    // MARK: Analytics Headers

    /// :nodoc:
    public func addHeaderProvider(
        _ headerProvider: @Sendable @escaping () async -> [String: String]
    ) {
        self.eventManager.addHeaderProvider(headerProvider)
    }

    private func makeHeaders() async -> [String: String] {
        var headers: [String: String] = [:]

        // Device info
        #if !os(watchOS)
        headers["X-UA-Device-Family"] = await UIDevice.current.systemName
        headers["X-UA-OS-Version"] = await UIDevice.current.systemVersion
        #else
        headers["X-UA-Device-Family"] =
            WKInterfaceDevice.current().systemName
        headers["X-UA-OS-Version"] =
            WKInterfaceDevice.current().systemVersion
        #endif

        headers["X-UA-Device-Model"] = AirshipUtils.deviceModelName()

        // App info
        if let infoDictionary = Bundle.main.infoDictionary {
            headers["X-UA-Package-Name"] =
                infoDictionary[kCFBundleIdentifierKey as String] as? String
        }

        headers["X-UA-Package-Version"] = AirshipUtils.bundleShortVersionString() ?? ""

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
        let extensions = self.sdkExtensions.value
        if extensions.count > 0 {
            headers["X-UA-Frameworks"] = extensions.joined(
                separator: ", "
            )
        }

        // Permissions
        for permission in self.permissionsManager.configuredPermissions {
            let status = await self.permissionsManager.checkPermissionStatus(permission)
            headers["X-UA-Permission-\(permission.stringValue)"] = status.stringValue
        }

        return headers
    }

    // MARK: -
    // MARK: Analytics Core Methods

    /// Triggers an analytics event.
    /// - Parameter event: The event to be triggered
    @objc
    public func addEvent(_ event: Event) {
        guard self.isAnalyticsEnabled else {
            AirshipLogger.trace(
                "Analytics disabled, ignoring event: \(event.eventType)"
            )
            return
        }

        guard let sessionID = self.sessionID else {
            AirshipLogger.error("Missing session ID")
            return
        }
        
        guard
            event.isValid?() != false,
            let body = try? AirshipJSON.wrap(event.data as? [String: Any])
        else {
            AirshipLogger.error("Dropping invalid event: \(event)")
            return
        }
        
        let eventData = AirshipEventData(
            body: body,
            id: NSUUID().uuidString,
            date: Date(),
            sessionID: sessionID,
            type: event.eventType
        )

        if let customEvent = event as? CustomEvent {
            self.notificationCenter.post(
                name: AirshipAnalytics.customEventAdded,
                object: self,
                userInfo: [AirshipAnalytics.eventKey: customEvent]
            )
        }

        if let regionEvent = event as? RegionEvent {
            self.notificationCenter.post(
                name: AirshipAnalytics.regionEventAdded,
                object: self,
                userInfo: [AirshipAnalytics.eventKey: regionEvent]
            )
        }

        self.serialQueue.enqueue {
            guard self.isAnalyticsEnabled else {
                return
            }

            do {
                AirshipLogger.debug("Adding event with type \(eventData.type)")
                AirshipLogger.trace("Adding event \(eventData)")
                try await self.eventManager.addEvent(eventData)
                self.eventSubject.send(eventData)
                await self.eventManager.scheduleUpload(
                    eventPriority: event.priority
                )
            } catch {
                AirshipLogger.error("Failed to save event \(error)")
                return
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
    public func associateDeviceIdentifiers(
        _ associatedIdentifiers: AssociatedIdentifiers
    ) {
        guard self.isAnalyticsEnabled else {
            AirshipLogger.warn(
                "Unable to associate identifiers \(associatedIdentifiers.allIDs) when analytics is disabled"
            )
            return
        }

        if let previous = self.dataStore.object(
            forKey: AirshipAnalytics.associatedIdentifiers
        ) as? [String: String] {
            if previous == associatedIdentifiers.allIDs {
                AirshipLogger.info(
                    "Skipping analytics event addition for duplicate associated identifiers."
                )
                return
            }
        }

        self.dataStore.setObject(
            associatedIdentifiers.allIDs,
            forKey: AirshipAnalytics.associatedIdentifiers
        )

        if let event = AssociateIdentifiersEvent(
            identifiers: associatedIdentifiers
        ) {
            self.addEvent(event)
        }
    }

    /// The device's current associated identifiers.
    /// - Returns: The device's current associated identifiers.
    @objc
    public func currentAssociatedDeviceIdentifiers() -> AssociatedIdentifiers {
        let storedIDs =
            self.dataStore.object(forKey: AirshipAnalytics.associatedIdentifiers)
            as? [String: String]
        return AssociatedIdentifiers(
            dictionary: storedIDs != nil ? storedIDs : [:]
        )
    }

    /// Initiates screen tracking for a specific app screen, must be called once per tracked screen.
    /// - Parameter screen: The screen's identifier.
    @objc
    public func trackScreen(_ screen: String?) {
        let date = self.date.now
        Task { @MainActor in
            // Prevent duplicate calls to track same screen
            guard screen != self.currentScreen else {
                return
            }

            self.notificationCenter.post(
                name: AirshipAnalytics.screenTracked,
                object: self,
                userInfo: screen == nil ? [:] : [AirshipAnalytics.screenKey: screen!]
            )

            // If there's a screen currently being tracked set it's stop time and add it to analytics
            if let currentScreen = self.currentScreen,
               let screenStartDate = self.screenStartDate {

                guard
                    let ste = ScreenTrackingEvent(
                        screen: currentScreen,
                        previousScreen: self.previousScreen,
                        startDate: screenStartDate,
                        duration: date.timeIntervalSince(screenStartDate)
                    )
                else {
                    AirshipLogger.error(
                        "Unable to create screen tracking event"
                    )
                    return
                }

                // Set previous screen to last tracked screen
                self.previousScreen = self.currentScreen

                // Add screen tracking event to next analytics batch
                self.addEvent(ste)
            }

            self.currentScreen = screen
            self.screenStartDate = date
        }
    }

    /// Registers an SDK extension with the analytics module.
    /// For internal use only. :nodoc:
    ///
    ///  - Parameters:
    ///   - ext: The SDK extension.
    ///   - version: The version.
    @objc
    public func registerSDKExtension(
        _ ext: AirshipSDKExtension,
        version: String
    ) {
        let sanitizedVersion = version.replacingOccurrences(of: ",", with: "")
        self.sdkExtensions.value.append("\(ext.name):\(sanitizedVersion)")
    }

    @objc
    private func updateEnablement() {
        guard self.isAnalyticsEnabled else {
            self.eventManager.uploadsEnabled = false
            Task {
                do {
                    try await self.eventManager.deleteEvents()
                } catch {
                    AirshipLogger.error("Failed to delete events \(error)")
                }
            }
            return
        }

        let uploadsEnabled = self.isAirshipReady && self.channel.identifier != nil


        if (self.eventManager.uploadsEnabled != uploadsEnabled) {
            self.eventManager.uploadsEnabled = uploadsEnabled

            if (uploadsEnabled) {
                Task {
                    await self.eventManager.scheduleUpload(
                        eventPriority: .normal
                    )
                }
            }
        }
    }

    private func startSession() {
        self.sessionID = NSUUID().uuidString
    }

    /// needed to ensure AppInit event gets added
    /// since App Clips get launched via Push Notification delegate
    @MainActor
    private func ensureInit() {
        if !self.initialized && self.isAirshipReady {
            self.addLifeCycleEvent(.appInit)
            self.initialized = true
        }
    }

    @MainActor
    public func airshipReady() {
        self.isAirshipReady = true

        // If analytics is initialized in the background state, we are responding to a
        // content-available push. If it's initialized in the foreground state takeOff
        // was probably called late. We should ensure an init event in either case.
        if self.appStateTracker.state != .inactive {
            ensureInit()
        }

        self.updateEnablement()
    }
}

extension AirshipAnalytics: InternalAnalyticsProtocol {
    /// Called to notify analytics the app was launched from a push notification.
    /// For internal use only. :nodoc:
    /// - Parameter notification: The push notification.
    @MainActor
    func launched(fromNotification notification: [AnyHashable: Any]) {
        if AirshipUtils.isAlertingPush(notification) {
            let sendID = notification["_"] as? String
            self.conversionSendID =
            sendID != nil ? sendID : AirshipAnalytics.missingSendID
            self.conversionPushMetadata =
            notification[AirshipAnalytics.pushMetadata] as? String
            self.ensureInit()
        } else {
            self.conversionSendID = nil
            self.conversionPushMetadata = nil
        }
    }

    func onDeviceRegistration(token: String) {
        guard privacyManager.isEnabled(.push) else {
            return
        }

        addEvent(
            DeviceRegistrationEvent(
                channelID: self.channel.identifier,
                deviceToken: token
            )
        )
    }

    @available(tvOS, unavailable)
    @MainActor
    func onNotificationResponse(
        response: UNNotificationResponse,
        action: UNNotificationAction?
    ) {
        let userInfo = response.notification.request.content.userInfo

        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            self.launched(fromNotification: userInfo)
        } else if let action = action {
            let categoryID = response.notification.request.content
                .categoryIdentifier
            let responseText = (response as? UNTextInputNotificationResponse)?
                .userText

            if action.options.contains(.foreground) == true {
                self.launched(fromNotification: userInfo)
            }

            addEvent(
                InteractiveNotificationEvent(
                    action: action,
                    category: categoryID,
                    notification: userInfo,
                    responseText: responseText
                )
            )
        }
    }

    @MainActor
    private func addLifeCycleEvent(_ type: LifeCycleEventType) {
        let event = self.lifeCycleEventFactory.make(type: type)
        addEvent(event)
    }
}

enum LifeCycleEventType {
    case appInit
    case foreground
    case background
}

protocol LifeCycleEventFactoryProtocol: Sendable {
    @MainActor
    func make(type: LifeCycleEventType) -> Event
}

fileprivate final class LifeCylceEventFactory: LifeCycleEventFactoryProtocol {
    @MainActor
    func make(type: LifeCycleEventType) -> Event {
        switch (type) {
        case .appInit:
            return AppInitEvent()
        case .background:
            return AppBackgroundEvent()
        case .foreground:
            return AppForegroundEvent()
        }
    }
}
