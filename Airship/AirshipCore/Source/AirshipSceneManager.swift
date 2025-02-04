/* Copyright Airship and Contributors */

import Foundation
#if !os(watchOS)
import UIKit
#endif

/// - Note: for internal use only.  :nodoc:
public protocol AirshipSceneManagerProtocol: Sendable {
#if !os(watchOS)
    @MainActor
    var lastActiveScene: UIWindowScene  { get throws }
#endif
}


/**
 *  Scene manager
 *  Monitors scene connection and disconnection notifications and associated scenes to allow retrieving the latest scene.
 */
/// - Note: for internal use only.  :nodoc:
public final class AirshipSceneManager: AirshipSceneManagerProtocol, @unchecked Sendable {
    public static let shared = AirshipSceneManager()

#if !os(watchOS)

    private var scenes: [UIWindowScene] = []

    private let notificationCenter: AirshipNotificationCenter

    internal init(notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter(notificationCenter: .default)) {
        self.notificationCenter = notificationCenter
        self.observeSceneEvents()
    }

    /**
     * Called to get the latest connected window scene
     *
     * @return A window scene
     */
    @MainActor
    public var lastActiveScene: UIWindowScene {
        get throws {
            let lastActiveMessageScene = scenes
                .filter { $0.activationState == .foregroundActive && $0.session.role == .windowApplication }
                .last

            guard let scene = lastActiveMessageScene else {
                return try Self.findWindowScene()
            }

            return scene
        }
    }

    // MARK: Notifications

    private func observeSceneEvents() {
        notificationCenter.addObserver(
            self,
            selector: #selector(sceneAdded),
            name: UIScene.willConnectNotification,
            object: nil
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(sceneRemoved),
            name: UIScene.didDisconnectNotification,
            object: nil
        )
    }

    // MARK: Helpers

    @objc
    @MainActor
    private func sceneAdded(_ notification: Notification) {
        guard let scene = notification.object as? UIWindowScene else {
            AirshipLogger.debug("Unable to cast UIWindowScene from notification UIScene.willConnectNotification")
            return
        }
        scenes.append(scene)
    }

    @objc
    @MainActor
    private func sceneRemoved(_ notification: Notification) {
        guard let scene = notification.object as? UIWindowScene else {
            AirshipLogger.debug("Unable to cast UIWindowScene from notification UIScene.didDisconnectNotification")
            return
        }
        scenes.removeAll { $0 == scene }
    }

    @MainActor
    fileprivate class func findWindowScene() throws -> UIWindowScene {
        guard
            let scene = UIApplication.shared.connectedScenes.first(where: {
                $0.isKind(of: UIWindowScene.self)
            }) as? UIWindowScene
        else {
            throw AirshipErrors.error("Unable to find a window!")
        }
        return scene
    }
#endif

}

