/* Copyright Airship and Contributors */

protocol RemoteConfigModuleAdapterProtocol {
    func setComponentsEnabled(_ enabled: Bool, module: RemoteConfigModule)
}

enum RemoteConfigModule: String, CaseIterable {
    case push
    case channel
    case analytics
    case messageCenter = "message_center"
    case inAppAutomation = "in_app_v2"
    case contact
}

/// Expected module names used in remote config.
class RemoteConfigModuleAdapter: RemoteConfigModuleAdapterProtocol {

    private func components(_ classes: [String]) -> [AirshipComponent] {
        return classes.compactMap {
            return Airship.component(forClassName: $0)
        }
    }

    private func components(_ module: RemoteConfigModule) -> [AirshipComponent] {
        switch module {
        case .push:
            return [Airship.push]
        case .channel:
            return [Airship.channel]
        case .analytics:
            return [Airship.analytics]
        case .messageCenter:
            return components(["UAMessageCenter"])
        case .inAppAutomation:
            return components(["UAInAppAutomation", "UALegacyInAppMessaging"])
        case .contact:
            return [Airship.contact]
        }
    }

    func setComponentsEnabled(_ enabled: Bool, module: RemoteConfigModule) {
        self.components(module).forEach { $0.isComponentEnabled = enabled }
    }
}
