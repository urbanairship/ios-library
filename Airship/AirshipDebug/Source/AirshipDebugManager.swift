/* Copyright Airship and Contributors */

import Combine
import SwiftUI
import UIKit

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif

public class AirshipDebugManager {
    public static var shared: AirshipDebugManager {
        return Airship.requireComponent(
            ofType: AirshipDebugManager.self
        )
    }

    private var currentDisplay: AirshipMainActorCancellable?
    private let pushDataManager: PushDataManager
    private let eventDataManager: EventDataManager
    private let remoteData: RemoteDataProtocol
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

    var inAppAutomationsPublisher: AnyPublisher<[[String: AnyHashable]], Never>
    {
        self.remoteData.publisher(types: ["in_app_messages"])
            .map { payloads -> [[String: AnyHashable]] in
                return payloads.compactMap { payload in
                    payload.data(key: "in_app_messages") as? [[String: AnyHashable]]
                }.reduce([], +)
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var experimentsPublisher: AnyPublisher<[[String: AnyHashable]], Never>
    {
        self.remoteData.publisher(types: ["experiments"])
            .map { payloads -> [[String: AnyHashable]] in
                return payloads.compactMap { payload in
                    payload.data(key: "experiments") as? [[String: AnyHashable]]
                }.reduce([], +)
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var featureFlagPublisher: AnyPublisher<[[String: AnyHashable]], Never>
    {
        self.remoteData.publisher(types: ["feature_flags"])
            .map { payloads -> [[String: AnyHashable]] in
                return payloads.compactMap { payload in
                    payload.data(key: "feature_flags") as? [[String: AnyHashable]]
                }.reduce([], +)
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    private let pushNotifiacitonReceivedSubject = PassthroughSubject<
        PushNotification, Never
    >()
    var pushNotifiacitonReceivedPublisher: AnyPublisher<PushNotification, Never>
    {
        return pushNotifiacitonReceivedSubject.eraseToAnyPublisher()
    }

    private let eventReceivedSubject = PassthroughSubject<AirshipEvent, Never>()
    var eventReceivedPublisher: AnyPublisher<AirshipEvent, Never> {
        return eventReceivedSubject.eraseToAnyPublisher()
    }

    init(
        config: RuntimeConfig,
        analytics: AirshipAnalyticsProtocol,
        remoteData: RemoteDataProtocol
    ) {
        self.remoteData = remoteData
        self.pushDataManager = PushDataManager(appKey: config.appKey)
        self.eventDataManager = EventDataManager(appKey: config.appKey)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        self.eventUpdates = analytics.eventPublisher
            .sink { incoming in
                guard
                    let body = try? incoming.body.toString(
                        encoder: encoder
                    )
                else {
                    return
                }

                let airshipEvent = AirshipEvent(
                    identifier: incoming.id,
                    type: incoming.type,
                    date: incoming.date,
                    body: body
                )

                self.eventDataManager.saveEvent(airshipEvent)
                self.eventReceivedSubject.send(airshipEvent)
            }

        self.observePayloadEvents()
    }

    func pushNotifications() async -> [PushNotification] {
        return await self.pushDataManager.pushNotifications()
    }

    func events(searchString: String? = nil) async -> [AirshipEvent] {
        return await self.eventDataManager.events(searchString: searchString)
    }

    @MainActor
    public func open() {
        guard let scene = try? AirshipSceneManager.shared.lastActiveScene else {
            AirshipLogger.error("Unable to display, missing scene.")
            return
        }

        currentDisplay?.cancel()

        var window: UIWindow? = UIWindow(windowScene: scene)
        let disposable = AirshipMainActorCancellableBlock {
            window?.windowLevel = .normal
            window?.isHidden = true
            window = nil
        }

        let viewController: UIViewController = UIHostingController(
            rootView: DebugRootView(disposable: disposable)
        )

        window?.windowLevel = .alert
        window?.makeKeyAndVisible()
        window?.rootViewController = viewController

        self.currentDisplay = disposable
    }

    func observePayloadEvents() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(receivedForegroundNotification(notification:)),
            name: AirshipPush.receivedForegroundNotificationEvent,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(receivedBackgroundNotification(notification:)),
            name: AirshipPush.receivedBackgroundNotificationEvent,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(receivedNotificationResponse(notification:)),
            name: AirshipPush.receivedNotificationResponseEvent,
            object: nil
        )
    }

    @objc func receivedForegroundNotification(notification: NSNotification) {
        guard let userInfo = notification.userInfo else {
            return
        }
        savePush(userInfo: userInfo)
    }

    @objc func receivedBackgroundNotification(notification: NSNotification) {
        guard let userInfo = notification.userInfo else {
            return
        }

        savePush(userInfo: userInfo)
    }

    @objc func receivedNotificationResponse(notification: NSNotification) {
        guard
            let response =
                notification.userInfo?[
                    AirshipPush.receivedNotificationResponseEventResponseKey
                ] as? UNNotificationResponse
        else {
            return
        }

        let push = response.notification.request.content.userInfo
        savePush(userInfo: push)
    }

    func savePush(userInfo: [AnyHashable: Any]) {
        guard let pushPayload = try? PushNotification(push: userInfo) else {
            return
        }

        self.pushNotifiacitonReceivedSubject.send(pushPayload)
        self.pushDataManager.savePushNotification(pushPayload)
    }
}

/// Adds IBInspectable to UILabel for use in storyboards.
///
/// Designer can enter a localization key in the storyboard attributes
/// inspector for the UILabel. This key will be used to localize the
/// UILabel's text when the storyboard is loaded.
extension UILabel {
    @IBInspectable var keyForLocalization: String? {
        // Don't need to ever get the key.
        get { return nil }
        // When the key is set by the storyboard, localize it
        // and set the localized text as the text of the UILabel
        set(key) {
            text = key?.localized()
        }
    }
}

/// Adds IBInspectable to UINavigationItem for use in storyboards.
///
/// Designer can enter a localization key in the storyboard attributes
/// inspector for the UINavigationItem. This key will be used to localize the
/// UINavigationItem's title when the storyboard is loaded.
extension UINavigationItem {
    @IBInspectable var keyForLocalization: String? {
        // Don't need to ever get the key.
        get { return nil }
        set(key) {
            // When the key is set by the storyboard, localize it
            // and set the localized text as the title of the UINavigationItem
            title = key?.localized()
        }
    }
}

/// Adds IBInspectable to UITextField for use in storyboards.
///
/// Designer can enter a localization key in the storyboard attributes
/// inspector for the UITextField. This key will be used to localize the
/// UITextField's placeholder when the storyboard is loaded.
extension UITextField {
    @IBInspectable var keyForLocalization: String? {
        // Don't need to ever get the key.
        get { return nil }
        set(key) {
            // When the key is set by the storyboard, localize it
            // and set the localized text as the placeholder of the UITextField
            placeholder = key?.localized()
        }
    }
}

private struct DebugRootView: View {
    let disposable: AirshipMainActorCancellable

    @ViewBuilder
    var body: some View {
        NavigationView {
            AirshipDebugView()
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            self.disposable.cancel()
                        }
                    }
                }
        }
        .navigationViewStyle(.stack)
    }
}


extension AirshipDebugManager: AirshipComponent {}
