/* Copyright Airship and Contributors */

import Combine

/// NOTE: For internal use only. :nodoc:
final class RemoteConfigManager: @unchecked Sendable {

    private let decoder = JSONDecoder()
    private var subscription: AnyCancellable?
    private let moduleAdapter: RemoteConfigModuleAdapterProtocol
    private let remoteData: RemoteDataProtocol
    private let privacyManager: AirshipPrivacyManager
    private let notificationCenter: AirshipNotificationCenter

    private let appVersion: String
    private let lock: AirshipLock = AirshipLock()
    private let config: RuntimeConfig

    init(
        config: RuntimeConfig,
        remoteData: RemoteDataProtocol,
        privacyManager: AirshipPrivacyManager,
        moduleAdapter: RemoteConfigModuleAdapterProtocol = RemoteConfigModuleAdapter(),
        notificationCenter: AirshipNotificationCenter = AirshipNotificationCenter.shared,
        appVersion: String = AirshipUtils.bundleShortVersionString() ?? ""
    ) {
        self.config = config
        self.remoteData = remoteData
        self.privacyManager = privacyManager
        self.moduleAdapter = moduleAdapter
        self.notificationCenter = notificationCenter
        self.appVersion = appVersion
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
        payloads?.forEach { payload in
            combinedData.merge((payload.data.unWrap() as? [String: AnyHashable] ?? [:])) { (_, new) in new }
        }

        // Disable features
        applyDisableInfos(combinedData)

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
                        return $0.evaluate(AirshipVersion.version)
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

    func applyRemoteConfig(_ data: [AnyHashable: Any]) {
        do {
            let data = try JSONSerialization.data(
                withJSONObject: data,
                options: []
            )
            let remoteConfig = try self.decoder.decode(
                RemoteConfig.self,
                from: data
            )
            Task { @MainActor [config] in
                config.updateRemoteConfig(remoteConfig)
            }
        } catch {
            AirshipLogger.error("Invalid remote config \(error)")
            return
        }
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
