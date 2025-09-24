/* Copyright Airship and Contributors */

@preconcurrency import Combine
import SwiftUI
import UIKit
public import AirshipCore


/// A protocol that provides access to Airship's debug interface functionality.
///
/// The `AirshipDebugManager` allows developers to display a comprehensive debug interface
/// that provides insights into various Airship SDK components including push notifications,
/// analytics events, channel information, contact data, and more.
///
/// ## Usage
///
/// ```swift
/// // Display the debug interface
/// Airship.debugManager.display()
/// ```
///
/// The debug interface will be presented as an overlay window that can be dismissed
/// by the user. It provides real-time monitoring and debugging capabilities for:
/// - Push notification history and details
/// - Analytics events and associated identifiers
/// - Channel tags, attributes, and subscription lists
/// - Contact information and channel management
/// - In-app experiences and automations
/// - Feature flags and experiments
/// - Preference centers
/// - App and SDK information
/// - Privacy manager settings
///
/// - Note: This protocol is thread-safe and can be called from any thread.
/// - Important: `Airship.takeOff` must be called before accessing the debug manager.
public protocol AirshipDebugManager: Sendable {
    /// Displays the Airship debug interface as an overlay window.
    ///
    /// This method presents a comprehensive debug interface that allows developers
    /// to inspect and monitor various aspects of the Airship SDK in real-time.
    /// The interface includes navigation to different debug sections and provides
    /// detailed information about push notifications, analytics events, channel
    /// data, and other SDK components.
    ///
    /// The debug interface will be displayed as a modal overlay window that can
    /// be dismissed by the user. If a debug interface is already displayed,
    /// calling this method will replace the current interface.
    ///
    /// - Note: This method must be called from the main thread.
    /// - Important: The debug interface requires an active scene to display properly.
    ///   If no active scene is available, an error will be logged and the interface
    ///   will not be displayed.
    @MainActor
    func display()
}

protocol InternalAirshipDebugManager: AirshipDebugManager {
    var preferenceFormsPublisher: AnyPublisher<[String], Never>  { get }

    var inAppAutomationsPublisher: AnyPublisher<[[String: AnyHashable]], Never> { get }

    var experimentsPublisher: AnyPublisher<[[String: AnyHashable]], Never> { get }

    var featureFlagPublisher: AnyPublisher<[[String: AnyHashable]], Never> { get }

    var pushNotificationReceivedPublisher: AnyPublisher<PushNotification, Never> { get }

    var eventReceivedPublisher: AnyPublisher<AirshipEvent, Never> { get }


    func pushNotifications() async -> [PushNotification]
    func events(searchString: String?) async -> [AirshipEvent]
    func events() async -> [AirshipEvent]

    @MainActor
    func receivedRemoteNotification(
        _ notification: AirshipJSON
    ) async -> UABackgroundFetchResult

#if !os(tvOS)
    func receivedNotificationResponse(
        _ response: UNNotificationResponse
    ) async
#endif

}

final class DefaultAirshipDebugManager: InternalAirshipDebugManager {

    @MainActor
    private var currentDisplay: (any AirshipMainActorCancellable)?
    private let pushDataManager: PushDataManager
    private let eventDataManager: EventDataManager
    private let remoteData: any RemoteDataProtocol

    @MainActor
    private var eventUpdates: AnyCancellable? = nil

    var preferenceFormsPublisher: AnyPublisher<[String], Never> {
        self.remoteData.publisher(types: ["preference_forms"])
            .map { payloads -> [String] in
                return payloads.compactMap { payload in
                    if let data = payload.data(key: "preference_forms") as? [[String: Any]] {
                        return data.compactMap { $0["form"] as? [String: Any] }
                            .compactMap { $0["id"] as? String }
                    } else {
                        return []
                    }
                }.reduce([], +)
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var inAppAutomationsPublisher: AnyPublisher<[[String: AnyHashable]], Never> {
        self.remoteData.publisher(types: ["in_app_messages"])
            .map { payloads -> [[String: AnyHashable]] in
                return payloads.compactMap { payload in
                    payload.data(key: "in_app_messages") as? [[String: AnyHashable]]
                }.reduce([], +)
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var experimentsPublisher: AnyPublisher<[[String: AnyHashable]], Never> {
        self.remoteData.publisher(types: ["experiments"])
            .map { payloads -> [[String: AnyHashable]] in
                return payloads.compactMap { payload in
                    payload.data(key: "experiments") as? [[String: AnyHashable]]
                }.reduce([], +)
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var featureFlagPublisher: AnyPublisher<[[String: AnyHashable]], Never> {
        self.remoteData.publisher(types: ["feature_flags"])
            .map { payloads -> [[String: AnyHashable]] in
                return payloads.compactMap { payload in
                    payload.data(key: "feature_flags") as? [[String: AnyHashable]]
                }.reduce([], +)
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    private let pushNotificationReceivedSubject = PassthroughSubject<PushNotification, Never>()
    var pushNotificationReceivedPublisher: AnyPublisher<PushNotification, Never> {
        return pushNotificationReceivedSubject.eraseToAnyPublisher()
    }

    private let eventReceivedSubject = PassthroughSubject<AirshipEvent, Never>()
    var eventReceivedPublisher: AnyPublisher<AirshipEvent, Never> {
        return eventReceivedSubject.eraseToAnyPublisher()
    }

    private let isEnabled: Bool

    @MainActor
    init(
        config: RuntimeConfig,
        analytics: any AirshipAnalytics,
        remoteData: any RemoteDataProtocol
    ) {
        self.remoteData = remoteData
        self.pushDataManager = PushDataManager(appKey: config.appCredentials.appKey)
        self.eventDataManager = EventDataManager(appKey: config.appCredentials.appKey)
        self.isEnabled = config.airshipConfig.isAirshipDebugEnabled

        guard self.isEnabled else { return }

        self.eventUpdates = analytics.eventPublisher
            .sink { incoming in
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted

                guard
                    let body = try? incoming.body.toString(
                        encoder: encoder
                    )
                else {
                    return
                }

                let airshipEvent = AirshipEvent(
                    identifier: incoming.id,
                    type: incoming.type.reportingName,
                    date: incoming.date,
                    body: body
                )

                Task { @MainActor in
                    await self.eventDataManager.saveEvent(airshipEvent)
                    self.eventReceivedSubject.send(airshipEvent)
                }
            }
    }

    func pushNotifications() async -> [PushNotification] {
        return await self.pushDataManager.pushNotifications()
    }

    func events(searchString: String?) async -> [AirshipEvent] {
        return await self.eventDataManager.events(searchString: searchString)
    }

    func events() async -> [AirshipEvent] {
        return await events(searchString: nil)
    }

    @MainActor
    public func display() {
        guard let scene = try? AirshipSceneManager.shared.lastActiveScene else {
            AirshipLogger.error("Unable to display, missing scene.")
            return
        }

        currentDisplay?.cancel()

        var window: UIWindow? = AirshipWindowFactory.shared.makeWindow(windowScene: scene)
        let disposable = AirshipMainActorCancellableBlock {
            window?.windowLevel = .normal
            window?.isHidden = true
            window = nil
        }

        let viewController: UIViewController = UIHostingController(
            rootView: AirshipDebugView {
                disposable.cancel()
            }
        )

        window?.windowLevel = .alert
        window?.makeKeyAndVisible()
        window?.rootViewController = viewController

        self.currentDisplay = disposable
    }

    @MainActor
    func receivedRemoteNotification(
        _ notification: AirshipJSON
    ) async -> UABackgroundFetchResult {

        guard self.isEnabled else {
            return .noData
        }

        do {
            let push = try PushNotification(userInfo: notification)
            try await savePush(push)
        } catch {
            AirshipLogger.error("Failed to save push \(error)")
        }
        return .noData
    }

#if !os(tvOS)
    func receivedNotificationResponse(
        _ response: UNNotificationResponse
    ) async {
        guard self.isEnabled else {
            return
        }

        do {
            let push = try PushNotification(
                userInfo: try AirshipJSON.wrap(
                    response.notification.request.content.userInfo
                )
            )
            try await savePush(push)
        } catch {
            AirshipLogger.error("Failed to save push \(error)")
        }
    }
#endif

    private func savePush(
        _ push: PushNotification
    ) async throws {
        await self.pushDataManager.savePushNotification(push)
        Task { @MainActor in
            self.pushNotificationReceivedSubject.send(push)
        }
    }
}


public extension Airship {
    /// The shared AirshipDebugManager instance.
    ///
    /// This property provides access to the Airship debug interface functionality,
    /// allowing developers to display a comprehensive debug UI for monitoring
    /// and debugging various aspects of the Airship SDK.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Display the debug interface
    /// Airship.debugManager.display()
    /// ```
    ///
    /// The debug manager provides access to:
    /// - Push notification history and details
    /// - Analytics events and associated identifiers  
    /// - Channel tags, attributes, and subscription lists
    /// - Contact information and channel management
    /// - In-app experiences and automations
    /// - Feature flags and experiments
    /// - Preference centers
    /// - App and SDK information
    /// - Privacy manager settings
    ///
    /// - Note: `Airship.takeOff` must be called before accessing this instance.
    /// - Important: This property will crash if accessed before Airship initialization.
    static var debugManager: any AirshipDebugManager {
        return Airship.requireComponent(ofType: DebugComponent.self).debugManager
    }
}


extension Airship {
    static var internalDebugManager: any InternalAirshipDebugManager {
        return Airship.requireComponent(ofType: DebugComponent.self).debugManager
    }
}
