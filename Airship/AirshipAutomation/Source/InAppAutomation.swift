/* Copyright Airship and Contributors */

public import Foundation
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif

@_spi(AirshipInternal) public import AirshipCore


/**
 * Provides a control interface for creating, canceling and executing in-app automations.
 */
public protocol InAppAutomation: AnyObject, Sendable {
    /// In-App Messaging
    var inAppMessaging: any InAppMessaging { get }

    /// Legacy In-App Messaging
    var legacyInAppMessaging: any LegacyInAppMessaging { get }

    /// Paused state of in-app automation.
    @MainActor
    var isPaused: Bool { get set }

    /// Creates the provided schedules or updates them if they already exist.
    /// - Parameter schedules: The schedules to create or update.
    func upsertSchedules(_ schedules: [AutomationSchedule]) async throws

    /// Cancels an in-app automation via its schedule identifier.
    /// - Parameter identifier: The schedule identifier to cancel.
    func cancelSchedule(identifier: String) async throws

    /// Cancels multiple in-app automations via their schedule identifiers.
    /// - Parameter identifiers: The schedule identifiers to cancel.
    func cancelSchedule(identifiers: [String]) async throws

    /// Cancels multiple in-app automations via their group.
    /// - Parameter group: The group to cancel.
    func cancelSchedules(group: String) async throws

    /// Gets the in-app automation with the provided schedule identifier.
    /// - Parameter identifier: The schedule identifier.
    /// - Returns: The in-app automation corresponding to the provided schedule identifier.
    func getSchedule(identifier: String) async throws -> AutomationSchedule?

    /// Gets the in-app automation with the provided group.
    /// - Parameter identifier: The group to get.
    /// - Returns: The in-app automation corresponding to the provided group.
    func getSchedules(group: String) async throws -> [AutomationSchedule]
    
    /// Inapp Automation status updates. Possible values are upToDate, stale and outOfDate.
    var statusUpdates: AsyncStream<InAppAutomationUpdateStatus> { get async }
    
    /// Current inApp Automation status. Possible values are upToDate, stale and outOfDate.
    var status: InAppAutomationUpdateStatus { get async }
    
    /// Allows to wait for the refresh of the InApp Automation rules.
    ///  - Parameters
    ///     - maxTime: Timeout in seconds.
    func waitRefresh(maxTime: TimeInterval?) async

    /// View-testing surface for displaying messages directly, bypassing the automation
    /// pipeline. Lives here rather than on `InAppMessaging` so it stays out of that
    /// app-facing (and test-mocked) protocol.
    /// - Note: For internal use only. :nodoc:
    @_spi(AirshipInternal)
    var viewTester: InAppMessageViewTester { get }
}

@_spi(AirshipInternal)
public extension InAppAutomation {
    /// Unavailable unless the concrete automation supplies a real tester (the default
    /// exists only to satisfy the `@_spi` requirement).
    var viewTester: InAppMessageViewTester { InAppMessageViewTester(executor: nil) }
}

/// Displays in-app messages directly for view-testing, bypassing the automation pipeline.
/// Reached via `Airship.inAppAutomation.viewTester`; wired with the message executor so it
/// reuses the real scene/display plumbing and the AI manager injected at module load.
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public struct InAppMessageViewTester: Sendable {
    private let executor: InAppMessageAutomationExecutor?

    init(executor: InAppMessageAutomationExecutor?) {
        self.executor = executor
    }

    /// Displays the message directly, bypassing the automation pipeline.
    @MainActor
    public func display(message: InAppMessage) async throws {
        guard let executor else {
            throw AirshipErrors.error("In-app message view testing is unavailable")
        }
        try await executor.displayTest(message: message)
    }
}

internal protocol InternalInAppAutomation: InAppAutomation {
    func cancelSchedulesWith(type: AutomationSchedule.ScheduleType) async throws
}

final class DefaultInAppAutomation: InternalInAppAutomation, Sendable {

    private let engine: any AutomationEngineProtocol
    private let remoteDataSubscriber: any AutomationRemoteDataSubscriberProtocol
    private let dataStore: PreferenceDataStore
    private let privacyManager: any AirshipPrivacyManager
    private let notificationCenter: AirshipNotificationCenter
    private static let pausedStoreKey: String = "UAInAppMessageManagerPaused"
    private let _legacyInAppMessaging: any InternalLegacyInAppMessaging
    private let remoteData: any RemoteDataProtocol

    /// In-App Messaging
    let inAppMessaging: any InAppMessaging

    /// View-testing display surface, injected at module load.
    let viewTester: InAppMessageViewTester

    /// Legacy In-App Messaging
    var legacyInAppMessaging: any LegacyInAppMessaging {
        return _legacyInAppMessaging
    }

    @MainActor
    init(
        engine: any AutomationEngineProtocol,
        inAppMessaging: any InAppMessaging,
        legacyInAppMessaging: any InternalLegacyInAppMessaging,
        remoteData: any RemoteDataProtocol,
        remoteDataSubscriber: any AutomationRemoteDataSubscriberProtocol,
        dataStore: PreferenceDataStore,
        privacyManager: any AirshipPrivacyManager,
        config: RuntimeConfig,
        viewTester: InAppMessageViewTester = InAppMessageViewTester(executor: nil),
        notificationCenter: AirshipNotificationCenter = .shared
    ) {
        self.engine = engine
        self.inAppMessaging = inAppMessaging
        self._legacyInAppMessaging = legacyInAppMessaging
        self.remoteDataSubscriber = remoteDataSubscriber
        self.dataStore = dataStore
        self.privacyManager = privacyManager
        self.notificationCenter = notificationCenter
        self.remoteData = remoteData
        self.viewTester = viewTester

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
    func upsertSchedules(_ schedules: [AutomationSchedule]) async throws {
        try await self.engine.upsertSchedules(schedules)
    }

    /// Cancels an in-app automation via its schedule identifier.
    /// - Parameter identifier: The schedule identifier to cancel.
    func cancelSchedule(identifier: String) async throws {
        try await self.engine.cancelSchedules(identifiers: [identifier])
    }

    /// Cancels multiple in-app automations via their schedule identifiers.
    /// - Parameter identifiers: The schedule identifiers to cancel.
    func cancelSchedule(identifiers: [String]) async throws {
        try await self.engine.cancelSchedules(identifiers: identifiers)
    }

    /// Cancels multiple in-app automations via their group.
    /// - Parameter group: The group to cancel.
    func cancelSchedules(group: String) async throws {
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

    /// Inapp Automation status updates. Possible values are upToDate, stale and outOfDate.
    public var statusUpdates: AsyncStream<InAppAutomationUpdateStatus> {
        get async {
            return await self.remoteData.statusUpdates(sources: [RemoteDataSource.app, RemoteDataSource.contact], map: { statuses in
                if statuses.values.contains(.outOfDate) {
                    return InAppAutomationUpdateStatus.outOfDate
                } else if statuses.values.contains(.stale) {
                    return InAppAutomationUpdateStatus.stale
                } else {
                    return InAppAutomationUpdateStatus.upToDate
                }
            })
        }
    }
    
    /// Current inApp Automation status. Possible values are upToDate, stale and outOfDate.
    public var status: InAppAutomationUpdateStatus {
        get async {
            let statuses = await self.remoteData.statusUpdates(sources: [RemoteDataSource.app, RemoteDataSource.contact], map: { statuses in
                if statuses.values.contains(.outOfDate) {
                    return InAppAutomationUpdateStatus.outOfDate
                } else if statuses.values.contains(.stale) {
                    return InAppAutomationUpdateStatus.stale
                } else {
                    return InAppAutomationUpdateStatus.upToDate
                }
            })
            
            return await statuses.first {_ in true } ?? .upToDate
        }
    }
    
    /// Allows to wait for the refresh of the InApp Automation rules.
    ///  - Parameters
    ///     - maxTime: Timeout in seconds.
    public func waitRefresh(maxTime: TimeInterval? = nil) async {
        await self.remoteData.waitRefresh(source: RemoteDataSource.app, maxTime: maxTime)
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

extension DefaultInAppAutomation {
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
    ) async -> UABackgroundFetchResult {
        return await self._legacyInAppMessaging.receivedRemoteNotification(notification)
    }

#if !os(tvOS)
    func receivedNotificationResponse(_ response: UNNotificationResponse) async {
        await self._legacyInAppMessaging.receivedNotificationResponse(response)
    }
#endif
}


public extension Airship {
    /// The shared `InAppAutomation` instance. `Airship.takeOff` must be called before accessing this instance.
    static var inAppAutomation: any InAppAutomation {
        return Airship.requireComponent(
            ofType: InAppAutomationComponent.self
        ).inAppAutomation
    }
}


