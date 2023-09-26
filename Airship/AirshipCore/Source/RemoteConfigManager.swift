/* Copyright Airship and Contributors */

import Combine

// NOTE: For internal use only. :nodoc:
final class RemoteConfigManager: @unchecked Sendable {

    @objc
    public static let remoteConfigUpdatedEvent = Notification.Name(
        "com.urbanairship.airship_remote_config_updated"
    )

    @objc
    public static let remoteConfigKey = "remote_config"

    private let decoder = JSONDecoder()
    private var subscription: AnyCancellable?
    private let moduleAdapter: RemoteConfigModuleAdapterProtocol
    private let remoteData: RemoteDataProtocol
    private let privacyManager: AirshipPrivacyManager
    private let appVersion: String
    private let notificationCenter: AirshipNotificationCenter
    private let lock = AirshipLock()

    init(
        remoteData: RemoteDataProtocol,
        privacyManager: AirshipPrivacyManager,
        moduleAdapter: RemoteConfigModuleAdapterProtocol = RemoteConfigModuleAdapter(),
        notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter.shared,
        appVersion: String = AirshipUtils.bundleShortVersionString() ?? ""
    ) {
        self.remoteData = remoteData
        self.privacyManager = privacyManager
        self.moduleAdapter = moduleAdapter
        self.appVersion = appVersion
        self.notificationCenter = notificationCenter
    }

    func airshipReady() {
        self.notificationCenter.addObserver(
            self,
            selector: #selector(updateRemoteConfigSubscription),
            name: AirshipPrivacyManager.changeEvent,
            object: nil
        )

        self.updateRemoteConfigSubscription()
    }

    func processRemoteConfig(_ payloads: [RemoteDataPayload]?) {
        var combinedData: [AnyHashable: Any] = [:]

        // Combine the data, overriding the common config (first) with
        // the platform config (second).
        payloads?
            .forEach { payload in
                combinedData.merge(payload.data) { (_, new) in new }
            }

        // Disable features
        applyDisableInfos(combinedData)

        // Module config
        applyConfigs(combinedData)

        //Remote config
        applyRemoteConfig(combinedData)
    }

    func applyDisableInfos(_ data: [AnyHashable: Any]) {
        let disableJSONArray = data["disable_features"] as? [[AnyHashable: Any]]
        let versionObject = ["ios": ["version": self.appVersion]]

        let disableInfos = disableJSONArray?
            .compactMap { return RemoteConfigDisableInfo(json: $0) }
            .filter { info in
                if info.appVersionConstraint?.evaluate(versionObject) == false {
                    return false
                }

                if !info.sdkVersionConstraints.isEmpty {
                    let matches = info.sdkVersionConstraints.contains(where: {
                        return $0.evaluate(AirshipVersion.get())
                    })
                    if !matches {
                        return false
                    }
                }

                return true
            }

        var disableModules: [RemoteConfigModule] = []
        var remoteDataRefreshInterval: TimeInterval = RemoteData.defaultRefreshInterval

        disableInfos?
            .forEach {
                disableModules.append(contentsOf: $0.disableModules)
                remoteDataRefreshInterval = max(
                    remoteDataRefreshInterval,
                    ($0.remoteDataRefreshInterval ?? 0.0)
                )
            }

        let disabled = Set(disableModules)
        disabled.forEach {
            moduleAdapter.setComponentsEnabled(false, module: $0)
        }

        let enabled = Set(RemoteConfigModule.allCases).subtracting(disabled)
        enabled.forEach { moduleAdapter.setComponentsEnabled(true, module: $0) }

        remoteData.remoteDataRefreshInterval = remoteDataRefreshInterval
    }

    func applyConfigs(_ data: [AnyHashable: Any]) {
        RemoteConfigModule.allCases.forEach {
            self.moduleAdapter.applyConfig(data[$0.rawValue], module: $0)
        }
    }

    func applyRemoteConfig(_ data: [AnyHashable: Any]) {
        guard let remoteConfigData = data["airship_config"] else {
            return
        }

        if let fetchContactData = data["fetch_contact_remote_data"] as? Bool {
            remoteData.setContactSourceEnabled(enabled: fetchContactData)
        }

        var parsedConfig: RemoteConfig?
        do {
            let data = try JSONSerialization.data(
                withJSONObject: remoteConfigData,
                options: []
            )
            parsedConfig = try self.decoder.decode(
                RemoteConfig.self,
                from: data
            )
        } catch {
            AirshipLogger.error("Invalid remote config \(error)")
            return
        }

        guard let remoteConfig = parsedConfig else {
            return
        }

        self.notificationCenter.post(
            name: RemoteConfigManager.remoteConfigUpdatedEvent,
            object: nil,
            userInfo: [RemoteConfigManager.remoteConfigKey: remoteConfig]
        )
    }

    @objc
    func updateRemoteConfigSubscription() {
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
