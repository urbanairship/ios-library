/* Copyright Airship and Contributors */

/// Defines disable info delivered in a remote config.
class RemoteConfigDisableInfo {
    
    let disableModules: [RemoteConfigModule]
    let appVersionConstraint: JSONPredicate?
    let sdkVersionConstraints: [VersionMatcher]
    let remoteDataRefreshInterval: TimeInterval?

    init(disableModules: [RemoteConfigModule],
         sdkVersionConstraints: [VersionMatcher],
         appVersionConstraint: JSONPredicate?,
         remoteDataRefreshInterval: TimeInterval?) {
        self.disableModules = disableModules
        self.sdkVersionConstraints = sdkVersionConstraints
        self.appVersionConstraint = appVersionConstraint
        self.remoteDataRefreshInterval = remoteDataRefreshInterval
    }

    convenience init?(json: [AnyHashable: Any]) {
        // Modules
        var disableModules: [RemoteConfigModule]?
        if let modules = json["modules"] {
            if (modules as? String == "all") {
                disableModules = RemoteConfigModule.allCases
            } else if let modules = modules as? [String] {
                disableModules = modules.compactMap { RemoteConfigModule(rawValue: $0) }
            } else {
                AirshipLogger.error("Invalid disableInfo: \(json)")
                return nil
            }
        }
        
        // App version constraint predicate
        var appVersionConstraint: JSONPredicate?
        if let versionConstraintJSON = json["app_versions"] {
            do {
                appVersionConstraint = try JSONPredicate(json: versionConstraintJSON)
            } catch {
                AirshipLogger.error("Invalid disableInfo: \(json) error: \(error)")
            }
        }
        
        // SDK version constraint predicate
        var sdkVersionConstraints: [VersionMatcher]?
        if let sdkVersionConstraintsJSON = json["sdk_versions"] {
            guard let array = sdkVersionConstraintsJSON as? [String] else {
                AirshipLogger.error("Invalid disableInfo: \(json)")
                return nil
            }
            
            sdkVersionConstraints = array.compactMap { VersionMatcher(versionConstraint: $0)}
        }
 
        var remoteDataRefreshInterval: TimeInterval?
        if let remoteDataRefreshIntervalJSON = json["remote_data_refresh_interval"] {
            if let interval = remoteDataRefreshIntervalJSON as? TimeInterval {
                remoteDataRefreshInterval = interval
            } else if let interval = remoteDataRefreshIntervalJSON as? Int {
                remoteDataRefreshInterval = TimeInterval(interval)
            } else {
                AirshipLogger.error("Invalid disableInfo: \(json)")
                return nil
            }
        }
        
        self.init(disableModules: disableModules ?? [],
                  sdkVersionConstraints: sdkVersionConstraints ?? [],
                  appVersionConstraint: appVersionConstraint,
                  remoteDataRefreshInterval: remoteDataRefreshInterval)
    }
}
