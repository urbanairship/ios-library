/* Copyright Airship and Contributors */

import Foundation
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AirshipCore)
public import AirshipCore
#endif


/**
 * Provides a control interface for creating, canceling and executing in-app automations.
 */
public final class InAppAutomation: Sendable {

    private let engine: any AutomationEngineProtocol
    private let remoteDataSubscriber: any AutomationRemoteDataSubscriberProtocol
    private let dataStore: PreferenceDataStore
    private let privacyManager: any PrivacyManagerProtocol
    private let notificationCenter: AirshipNotificationCenter
    private static let pausedStoreKey: String = "UAInAppMessageManagerPaused"
    private let _legacyInAppMessaging: any InternalLegacyInAppMessagingProtocol

    /// In-App Messaging
    public let inAppMessaging: any InAppMessagingProtocol

    /// Legacy In-App Messaging
    public var legacyInAppMessaging: any LegacyInAppMessagingProtocol {
        return _legacyInAppMessaging
    }

    /// The shared InAppAutomation instance. `Airship.takeOff` must be called before accessing this instance.
    @available(*, deprecated, message: "Use Airship.inAppAutomation instead")
    public static var shared: InAppAutomation {
        return Airship.inAppAutomation
    }

    @MainActor
    init(
        engine: any AutomationEngineProtocol,
        inAppMessaging: any InAppMessagingProtocol,
        legacyInAppMessaging: any InternalLegacyInAppMessagingProtocol,
        remoteDataSubscriber: any AutomationRemoteDataSubscriberProtocol,
        dataStore: PreferenceDataStore,
        privacyManager: any PrivacyManagerProtocol,
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

        if (config.airshipConfig.autoPauseInAppAutomationOnLaunch) {
            self.isPaused = true
        }
    }

    /// Paused state of in-app automation.
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

    /// Creates the provided schedules or updates them if they already exist.
    /// - Parameter schedules: The schedules to create or update.
    public func upsertSchedules(_ schedules: [AutomationSchedule]) async throws {
        try await self.engine.upsertSchedules(schedules)
    }

    /// Cancels an in-app automation via its schedule identifier.
    /// - Parameter identifier: The schedule identifier to cancel.
    public func cancelSchedule(identifier: String) async throws {
        try await self.engine.cancelSchedules(identifiers: [identifier])
    }

    /// Cancels multiple in-app automations via their schedule identifiers.
    /// - Parameter identifiers: The schedule identifiers to cancel.
    public func cancelSchedule(identifiers: [String]) async throws {
        try await self.engine.cancelSchedules(identifiers: identifiers)
    }

    /// Cancels multiple in-app automations via their group.
    /// - Parameter group: The group to cancel.
    public func cancelSchedules(group: String) async throws {
        try await self.engine.cancelSchedules(group: group)
    }

    func cancelSchedulesWith(type: AutomationSchedule.ScheduleType) async throws {
        try await self.engine.cancelSchedulesWith(type: type)
    }

    /// Gets the in-app automation with the provided schedule identifier.
    /// - Parameter identifier: The schedule identifier.
    /// - Returns: The in-app automation corresponding to the provided schedule identifier.
    public func getSchedule(identifier: String) async throws -> AutomationSchedule? {
        return try await self.engine.getSchedule(identifier: identifier)
    }

    /// Gets the in-app automation with the provided group.
    /// - Parameter identifier: The group to get.
    /// - Returns: The in-app automation corresponding to the provided group.
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

extension InAppAutomation {
    @MainActor
    func airshipReady() {
        self.engine.setExecutionPaused(self.isPaused)

        Task {
            await self.engine.start()
        }

        self.notificationCenter.addObserver(forName: AirshipNotifications.PrivacyManagerUpdated.name) { [weak self] _ in
            Task { @MainActor in
                self?.privacyManagerUpdated()
            }
        }
        self.privacyManagerUpdated()
    }

    func receivedRemoteNotification(
        _ notification: AirshipJSON // wrapped [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        return await self._legacyInAppMessaging.receivedRemoteNotification(notification)
    }

#if !os(tvOS)
    func receivedNotificationResponse(_ response: UNNotificationResponse) async {
        await self._legacyInAppMessaging.receivedNotificationResponse(response)
    }
#endif
}


public extension Airship {
    /// The shared InAppAutomation instance. `Airship.takeOff` must be called before accessing this instance.
    static var inAppAutomation: InAppAutomation {
        return Airship.requireComponent(ofType: InAppAutomationComponent.self).inAppAutomation
    }
}
