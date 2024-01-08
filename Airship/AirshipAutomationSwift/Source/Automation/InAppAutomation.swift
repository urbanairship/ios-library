import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

public final class InAppAutomation: Sendable {
    private let engine: AutomationEngineProtocol
    private let remoteDataScheduler: AutomationRemoteDataSchedulerProtocol
    private let dataStore: PreferenceDataStore
    private let privacyManager: AirshipPrivacyManager
    private let notificationCenter: AirshipNotificationCenter
    private static let pausedStoreKey: String = "UAInAppMessageManagerPaused"

    /// In-App Messaging
    public let inAppMessaging: InAppMessagingProtocol

    @MainActor
    init(
        engine: AutomationEngineProtocol,
        inAppMessaging: InAppMessagingProtocol,
        remoteDataScheduler: AutomationRemoteDataSchedulerProtocol,
        dataStore: PreferenceDataStore,
        privacyManager: AirshipPrivacyManager,
        config: RuntimeConfig,
        notificationCenter: AirshipNotificationCenter = .shared
    ) {
        self.engine = engine
        self.inAppMessaging = inAppMessaging
        self.remoteDataScheduler = remoteDataScheduler
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

    @MainActor
    private func privacyManagerUpdated() {
        if self.privacyManager.isEnabled(.inAppAutomation) {
            self.engine.isPaused = false
            self.remoteDataScheduler.subscribe()
            engine.scheduleConditionsChanged()
        } else {
            self.engine.isPaused = true
            self.remoteDataScheduler.unsubscribe()
        }
    }
}
