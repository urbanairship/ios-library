import Foundation

@testable import AirshipCore

class TestRemoteConfigModuleAdapter: RemoteConfigModuleAdapterProtocol {

    var enabledModules: Set<RemoteConfigModule> = Set()
    var disabledModules: Set<RemoteConfigModule> = Set()

    public func setComponentsEnabled(
        _ enabled: Bool,
        module: RemoteConfigModule
    ) {
        if enabled {
            enabledModules.insert(module)
            disabledModules.remove(module)
        } else {
            enabledModules.remove(module)
            disabledModules.insert(module)
        }
    }
}
