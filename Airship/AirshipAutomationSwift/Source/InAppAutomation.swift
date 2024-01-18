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

    /// In-App Messaging
    public let inAppMessaging: InAppMessagingProtocol

    /// Legacy In-App Messaging
    public let legacyInAppMessaging: LegacyInAppMessagingProtocol

    @MainActor
    init(
        engine: AutomationEngineProtocol,
        inAppMessaging: InAppMessagingProtocol,
        legacyInAppMessaging: LegacyInAppMessagingProtocol,
        remoteDataSubscriber: AutomationRemoteDataSubscriberProtocol,
        dataStore: PreferenceDataStore,
        privacyManager: AirshipPrivacyManager,
        config: RuntimeConfig,
        notificationCenter: AirshipNotificationCenter = .shared
    ) {
        self.engine = engine
        self.inAppMessaging = inAppMessaging
        self.legacyInAppMessaging = legacyInAppMessaging
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
            self.engine.isExecutionPaused = newValue
        }
    }

    @MainActor
    func onAirshipReady() {
        self.engine.isExecutionPaused = self.isPaused
        self.engine.start()
        self.notificationCenter.addObserver(forName: AirshipPrivacyManager.changeEvent) { _ in
            self.privacyManagerUpdated()
        }
    }

    public func upsertSchedules(_ schedules: [AutomationSchedule]) async throws {
        try await self.engine.upsertSchedules(schedules)
    }

    public func cancelSchedule(identifier: String) async throws {
        try await self.engine.cancelSchedule(identifier: identifier)
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
            self.engine.isPaused = false
            self.remoteDataSubscriber.subscribe()
            engine.scheduleConditionsChanged()
        } else {
            self.engine.isPaused = true
            self.remoteDataSubscriber.unsubscribe()
        }
    }

    /// TODO, call throught to LegacyIAA with pushable component callbacks
}
