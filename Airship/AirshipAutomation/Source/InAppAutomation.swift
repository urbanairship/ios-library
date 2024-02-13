import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

public final class InAppAutomation: Sendable {

    private let engine: AutomationEngineProtocol
    private let remoteDataSubscriber: AutomationRemoteDataSubscriberProtocol
    private let dataStore: PreferenceDataStore
    private let privacyManager: AirshipPrivacyManager
    private let notificationCenter: AirshipNotificationCenter
    private static let pausedStoreKey: String = "UAInAppMessageManagerPaused"
    private let _legacyInAppMessaging: InternalLegacyInAppMessagingProtocol

    /// In-App Messaging
    public let inAppMessaging: InAppMessagingProtocol

    /// Legacy In-App Messaging
    public var legacyInAppMessaging: LegacyInAppMessagingProtocol {
        return _legacyInAppMessaging
    }

    /// The shared InAppAutomation instance. `Airship.takeOff` must be called before accessing this instance.
    public static var shared: InAppAutomation {
        return Airship.requireComponent(ofType: InAppAutomation.self)
    }

    @MainActor
    init(
        engine: AutomationEngineProtocol,
        inAppMessaging: InAppMessagingProtocol,
        legacyInAppMessaging: InternalLegacyInAppMessagingProtocol,
        remoteDataSubscriber: AutomationRemoteDataSubscriberProtocol,
        dataStore: PreferenceDataStore,
        privacyManager: AirshipPrivacyManager,
        config: RuntimeConfig,
        notificationCenter: AirshipNotificationCenter = .shared
    ) {
        self.engine = engine
        self.inAppMessaging = inAppMessaging
        self._legacyInAppMessaging = legacyInAppMessaging
        self.remoteDataSubscriber = remoteDataSubscriber
        self.dataStore = dataStore
        self.privacyManager = privacyManager
        self.notificationCenter = notificationCenter

        if (config.autoPauseInAppAutomationOnLaunch) {
            self.isPaused = true
        }
    }

    @MainActor
    public var isPaused: Bool {
        get {
            return self.dataStore.bool(forKey: Self.pausedStoreKey)
        }
        set {
            self.dataStore.setBool(newValue, forKey: Self.pausedStoreKey)
            self.engine.setExecutionPaused(newValue)
        }
    }

    public func upsertSchedules(_ schedules: [AutomationSchedule]) async throws {
        try await self.engine.upsertSchedules(schedules)
    }

    public func cancelSchedule(identifier: String) async throws {
        try await self.engine.cancelSchedules(identifiers: [identifier])
    }

    public func cancelSchedule(identifiers: [String]) async throws {
        try await self.engine.cancelSchedules(identifiers: identifiers)
    }

    public func cancelSchedules(group: String) async throws {
        try await self.engine.cancelSchedules(group: group)
    }

    public func getSchedule(identifier: String) async throws -> AutomationSchedule? {
        return try await self.engine.getSchedule(identifier: identifier)
    }

    public func getSchedules(group: String) async throws -> [AutomationSchedule] {
        return try await self.engine.getSchedules(group: group)
    }

    @MainActor
    private func privacyManagerUpdated() {
        if self.privacyManager.isEnabled(.inAppAutomation) {
            self.engine.setEnginePaused(false)
            self.remoteDataSubscriber.subscribe()
        } else {
            self.engine.setEnginePaused(true)
            self.remoteDataSubscriber.unsubscribe()
        }
    }
}

extension InAppAutomation: AirshipComponent, AirshipPushableComponent {
    @MainActor
    public func airshipReady() {
        self.engine.setExecutionPaused(self.isPaused)

        Task {
            await self.engine.start()
        }

        self.notificationCenter.addObserver(forName: AirshipPrivacyManager.changeEvent) { [weak self] _ in
            self?.privacyManagerUpdated()
        }
        self.privacyManagerUpdated()
    }

    public func receivedRemoteNotification(
        _ notification: [AnyHashable: Any],
        completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        self._legacyInAppMessaging.receivedRemoteNotification(notification, completionHandler: completionHandler)
    }

    public func receivedNotificationResponse(_ response: UNNotificationResponse, completionHandler: @escaping () -> Void) {
        self._legacyInAppMessaging.receivedNotificationResponse(response, completionHandler: completionHandler)
    }
}


