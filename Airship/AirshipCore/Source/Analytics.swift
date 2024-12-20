/* Copyright Airship and Contributors */

import Combine
import Foundation
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif


/// The Analytics object provides an interface to the Airship Analytics API.
final class AirshipAnalytics: AirshipAnalyticsProtocol, @unchecked Sendable {
    private static let associatedIdentifiers = "UAAssociatedIdentifiers"

    static let missingSendID = "MISSING_SEND_ID"
    static let pushMetadata = "com.urbanairship.metadata"
    static let pushSendID = "_"

    private let config: RuntimeConfig
    private let dataStore: PreferenceDataStore
    private let channel: any AirshipChannelProtocol
    private let privacyManager: AirshipPrivacyManager
    private let notificationCenter: AirshipNotificationCenter
    private let date: any AirshipDateProtocol
    private let eventManager: any EventManagerProtocol
    private let localeManager: any AirshipLocaleManagerProtocol
    private let permissionsManager: AirshipPermissionsManager
    private let sessionTracker: any SessionTrackerProtocol
    private let serialQueue: AirshipAsyncSerialQueue = AirshipAsyncSerialQueue()

    private let sdkExtensions: AirshipAtomicValue<[String]> = AirshipAtomicValue([])

    // Screen tracking state
    private let screenState: AirshipMainActorValue<ScreenState> = AirshipMainActorValue(ScreenState())
    private let restoreScreenOnForeground: AirshipMainActorValue<String?> = AirshipMainActorValue(nil)

    private let regions: AirshipMainActorValue<Set<String>> = AirshipMainActorValue(Set())


    private var isAirshipReady = false

    /// The conversion send ID. :nodoc:
   public var conversionSendID: String? {
       return self.sessionTracker.sessionState.conversionSendID
    }

   /// The conversion push metadata. :nodoc:
   public var conversionPushMetadata: String? {
       return self.sessionTracker.sessionState.conversionMetadata
   }

    /// The current session ID.
    public var sessionID: String {
        return self.sessionTracker.sessionState.sessionID
    }

    private let eventSubject = PassthroughSubject<AirshipEventData, Never>()

    /// Airship event publisher
    public var eventPublisher: AnyPublisher<AirshipEventData, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    public let eventFeed: AirshipAnalyticsFeed

    private var isAnalyticsEnabled: Bool {
        return self.privacyManager.isEnabled(.analytics) &&
        self.config.airshipConfig.isAnalyticsEnabled
    }

    @MainActor
    convenience init(
        config: RuntimeConfig,
        dataStore: PreferenceDataStore,
        channel: any AirshipChannelProtocol,
        localeManager: any AirshipLocaleManagerProtocol,
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
            eventManager: EventManager(
                config: config,
                dataStore: dataStore,
                channel: channel
            )
        )
    }

    @MainActor
    init(
        config: RuntimeConfig,
        dataStore: PreferenceDataStore,
        channel: any AirshipChannelProtocol,
        notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter.shared,
        date: any AirshipDateProtocol = AirshipDate.shared,
        localeManager: any AirshipLocaleManagerProtocol,
        privacyManager: AirshipPrivacyManager,
        permissionsManager: AirshipPermissionsManager,
        eventManager: any EventManagerProtocol,
        sessionTracker: (any SessionTrackerProtocol)? = nil,
        sessionEventFactory: any SessionEventFactoryProtocol = SessionEventFactory()
    ) {
        self.config = config
        self.dataStore = dataStore
        self.channel = channel
        self.notificationCenter = notificationCenter
        self.date = date
        self.localeManager = localeManager
        self.privacyManager = privacyManager
        self.permissionsManager = permissionsManager
        self.eventManager = eventManager
        self.sessionTracker = sessionTracker ?? SessionTracker()
        self.eventFeed = AirshipAnalyticsFeed(
            privacyManager: privacyManager,
            isAnalyticsEnabled: config.airshipConfig.isAnalyticsEnabled
        )

        self.eventManager.addHeaderProvider {
            await self.makeHeaders()
        }

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
            name: AirshipNotifications.PrivacyManagerUpdated.name,
            object: nil
        )

        self.notificationCenter.addObserver(
            self,
            selector: #selector(updateEnablement),
            name: AirshipNotifications.ChannelCreated.name,
            object: nil
        )

        Task { @MainActor [weak self, tracker = self.sessionTracker] in
            for await event in tracker.events {
                guard let self else {
                    return
                }
                self.recordEvent(
                    sessionEventFactory.make(event: event),
                    date: event.date,
                    sessionID: event.sessionState.sessionID
                )
            }
        }
    }

    @objc
    @MainActor
    private func applicationWillEnterForeground() {
        // Start tracking previous screen before backgrounding began
        if let previousScreen = self.restoreScreenOnForeground.value,
           self.screenState.value.current == nil
        {
            trackScreen(previousScreen)
        }
        self.restoreScreenOnForeground.set(nil)
    }

    @objc
    @MainActor
    private func applicationDidEnterBackground() {
        self.restoreScreenOnForeground.set(self.screenState.value.current)
        self.trackScreen(nil)
    }

    @objc
    @MainActor
    private func applicationWillTerminate() {
        self.trackScreen(nil)
    }


    // MARK: -
    // MARK: Analytics Headers

    /// :nodoc:
    @MainActor
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
        headers["X-UA-Locale-Language"] = currentLocale.getLanguageCode()
        headers["X-UA-Locale-Country"] = currentLocale.getRegionCode()
        headers["X-UA-Locale-Variant"] = currentLocale.getVariantCode()

        // Airship identifiers
        headers["X-UA-Channel-ID"] = self.channel.identifier
        headers["X-UA-App-Key"] = self.config.appCredentials.appKey

        // SDK Version
        headers["X-UA-Lib-Version"] = AirshipVersion.version

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
            headers["X-UA-Permission-\(permission.rawValue)"] = status.rawValue
        }

        return headers
    }

    public func recordCustomEvent(_ event: CustomEvent) {
        guard self.isAnalyticsEnabled else {
            AirshipLogger.info(
                "Analytics disabled, ignoring custom event \(event)"
            )
            return
        }

        guard event.isValid() else {
            AirshipLogger.info(
                "Custom event is invalid, ignoring custom event \(event)"
            )
            return
        }

        recordEvent(
            AirshipEvent(
                eventType: .customEvent,
                eventData: event.eventBody(
                    sendID: self.conversionSendID,
                    metadata: self.conversionPushMetadata,
                    formatValue: true
                )
            ),
            feedEvent: .analytics(
                eventType: .customEvent,
                body: event.eventBody(
                    sendID: self.conversionSendID,
                    metadata: self.conversionPushMetadata,
                    formatValue: false
                ),
                value: event.eventValue?.doubleValue
            ),
            date: self.date.now,
            sessionID: self.sessionTracker.sessionState.sessionID
        )
    }

    public func recordRegionEvent(_ event: RegionEvent) {
        let shouldInsert: Bool = event.boundaryEvent == .enter
        let regionID = event.regionID

        Task { @MainActor in
            self.regions.update { regions in
                if (shouldInsert) {
                    regions.insert(regionID)
                } else {
                    regions.remove(regionID)
                }
            }
        }

        guard self.isAnalyticsEnabled else {
            AirshipLogger.info(
                "Analytics disabled, ignoring region event \(event)"
            )
            return
        }

        /// Upload
        do {
            let eventType: EventType = switch(event.boundaryEvent) {
            case .enter: .regionEnter
            case .exit: .regionExit
            }
            recordEvent(
                AirshipEvent(
                    eventType: eventType,
                    eventData: try event.eventBody(stringifyFields: true)
                )
            )
        } catch {
            AirshipLogger.error("Failed to generate event body \(error)")
        }
    }

    public func trackInstallAttribution(
        appPurchaseDate: Date?,
        iAdImpressionDate: Date?
    ) {
        recordEvent(
            AirshipEvents.installAttirbutionEvent(
                appPurchaseDate: appPurchaseDate,
                iAdImpressionDate: iAdImpressionDate
            )
        )
    }

    public func recordEvent(_ event: AirshipEvent) {
        self.recordEvent(
            event,
            date: self.date.now,
            sessionID: self.sessionTracker.sessionState.sessionID
        )
    }

    private func recordEvent(
        _ event: AirshipEvent,
        date: Date,
        sessionID: String
    ) {
        self.recordEvent(
            event,
            feedEvent: AirshipAnalyticsFeed.Event.analytics(
                eventType: event.eventType,
                body: event.eventData,
                value: nil
            ),
            date: date,
            sessionID: sessionID
        )
    }

    

    private func recordEvent(
        _ event: AirshipEvent,
        feedEvent: AirshipAnalyticsFeed.Event,
        date: Date,
        sessionID: String
    ) {
        self.serialQueue.enqueue {
            guard self.isAnalyticsEnabled else {
                AirshipLogger.trace(
                    "Analytics disabled, ignoring event: \(event.eventType)"
                )
                return
            }

            await self.eventFeed.notifyEvent(feedEvent)

            let eventData = AirshipEventData(
                body: event.eventData,
                id: NSUUID().uuidString,
                date: date,
                sessionID: sessionID,
                type: event.eventType
            )

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

        do {
            let event = try AirshipEvents.associatedIdentifiersEvent(
                identifiers: associatedIdentifiers
            )
            self.recordEvent(event)
            self.dataStore.setObject(
                associatedIdentifiers.allIDs,
                forKey: AirshipAnalytics.associatedIdentifiers
            )
        } catch {
            AirshipLogger.error("Failed to add associated idenfiers event \(error)")
        }
    }

    /// The device's current associated identifiers.
    /// - Returns: The device's current associated identifiers.
    public func currentAssociatedDeviceIdentifiers() -> AssociatedIdentifiers {
        let storedIDs =
            self.dataStore.object(forKey: AirshipAnalytics.associatedIdentifiers)
            as? [String: String]
        return AssociatedIdentifiers(
            identifiers: storedIDs ?? [:]
        )
    }

    /// Initiates screen tracking for a specific app screen, must be called once per tracked screen.
    /// - Parameter screen: The screen's identifier.
    @MainActor
    public func trackScreen(_ screen: String?) {
        let date = self.date.now
        // Prevent duplicate calls to track same screen
        guard screen != self.screenState.value.current else {
            return
        }

        Task {
            await self.eventFeed.notifyEvent(.screen(screen: screen))
        }

        let currentScreen = self.screenState.value.current
        let screenStartDate = self.screenState.value.startDate
        let previousScreen = self.screenState.value.previous

        self.screenState.update { state in
            state.current = screen
            state.startDate = date
            state.previous = currentScreen
        }

        // If there's a screen currently being tracked set it's stop time and add it to analytics
        if let currentScreen = currentScreen, let screenStartDate = screenStartDate {
            do {
                let ste = try AirshipEvents.screenTrackingEvent(
                    screen: currentScreen,
                    previousScreen: previousScreen,
                    startDate: screenStartDate,
                    duration: date.timeIntervalSince(screenStartDate)
                )

                // Add screen tracking event to next analytics batch
                self.recordEvent(ste)
            } catch {
                AirshipLogger.error(
                    "Unable to create screen tracking event \(error)"
                )
            }
        }
    }

    /// Registers an SDK extension with the analytics module.
    /// For internal use only. :nodoc:
    ///
    ///  - Parameters:
    ///   - ext: The SDK extension.
    ///   - version: The version.
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
}


extension AirshipAnalytics: AirshipComponent, InternalAnalyticsProtocol {
    @MainActor
    public func airshipReady() {
        self.isAirshipReady = true
        self.updateEnablement()

        self.sessionTracker.airshipReady()
    }

    @MainActor
    public var currentScreen: String? {
        return self.screenState.value.current
    }
    
    @MainActor
    public var regionUpdates: AsyncStream<Set<String>> {
        return self.regions.updates
    }
    
    @MainActor
    public var currentRegions: Set<String> {
        return self.regions.value
    }

    @MainActor
    public var screenUpdates: AsyncStream<String?> {
        return AsyncStream { [screenState] continutation in
            let updates = screenState.updates
            let task = Task {
                for await value in updates {
                    continutation.yield(value.current)
                }
            }

            continutation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Called to notify analytics the app was launched from a push notification.
    /// For internal use only. :nodoc:
    /// - Parameter notification: The push notification.
    @MainActor
    public func launched(fromNotification notification: [AnyHashable: Any]) {
        if AirshipUtils.isAlertingPush(notification) {
            let sendID = notification[AirshipAnalytics.pushSendID] as? String
            let metadata = notification[AirshipAnalytics.pushMetadata] as? String

            self.sessionTracker.launchedFromPush(
                sendID: sendID ?? AirshipAnalytics.missingSendID,
                metadata: metadata
            )
        }
    }

    public func onDeviceRegistration(token: String) {
        recordEvent(
            AirshipEvents.deviceRegistrationEvent(
                channelID: self.channel.identifier,
                deviceToken: token
            )
        )
    }

    @available(tvOS, unavailable)
    @MainActor
    public func onNotificationResponse(
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

            #if !os(tvOS)
            recordEvent(
                AirshipEvents.interactiveNotificationEvent(
                    action: action,
                    category: categoryID,
                    notification: userInfo,
                    responseText: responseText
                )
            )
            #endif
        }
    }
}


fileprivate struct ScreenState {
    var current: String?
    var previous: String?
    var startDate: Date?
}
