/* Copyright Airship and Contributors */

import Combine
import Foundation

/// NOTE: For internal use only. :nodoc:
final class RemoteConfigManager: @unchecked Sendable {

    private var subscription: AnyCancellable?
    private let remoteData: any RemoteDataProtocol
    private let privacyManager: any AirshipPrivacyManager
    private let notificationCenter: AirshipNotificationCenter

    private let appVersion: String
    private let lock: AirshipLock = AirshipLock()
    private let config: RuntimeConfig

    init(
        config: RuntimeConfig,
        remoteData: any RemoteDataProtocol,
        privacyManager: any AirshipPrivacyManager,
        notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter.shared,
        appVersion: String = AirshipUtils.bundleShortVersionString() ?? ""
    ) {
        self.config = config
        self.remoteData = remoteData
        self.privacyManager = privacyManager
        self.notificationCenter = notificationCenter
        self.appVersion = appVersion
    }

    func airshipReady() {
        self.notificationCenter.addObserver(
            self,
            selector: #selector(updateRemoteConfigSubscription),
            name: AirshipNotifications.PrivacyManagerUpdated.name,
            object: nil
        )

        self.updateRemoteConfigSubscription()
    }

    func processRemoteConfig(_ payloads: [RemoteDataPayload]?) {
        var combinedData: [String: Any] = [:]

        // Combine the data, overriding the common config (first) with
        // the platform config (second).
        payloads?.forEach { payload in
            combinedData.merge((payload.data.object ?? [:])) { (_, new) in new }
        }

        //Remote config
        applyRemoteConfig(combinedData)
    }

    private func applyRemoteConfig(_ data: [String: Any]) {
        do {
            let remoteConfig: RemoteConfig = try AirshipJSON.wrap(data).decode()
            Task { @MainActor [config] in
                config.updateRemoteConfig(remoteConfig)
            }
        } catch {
            AirshipLogger.error("Invalid remote config \(error)")
            return
        }
    }

    @objc
    private func updateRemoteConfigSubscription() {
        lock.sync {
            if self.privacyManager.isAnyFeatureEnabled() {
                if self.subscription == nil {
                    self.subscription = self.remoteData.publisher(
                        types: ["app_config", "app_config:ios"]
                    )
                    .removeDuplicates()
                    .sink { [weak self] remoteConfig in
                        self?.processRemoteConfig(remoteConfig)
                    }
                }
            } else {
                self.subscription?.cancel()
                self.subscription = nil
            }
        }
    }
}
