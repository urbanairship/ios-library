/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
@objc(UASDKDependencyKeys)
public class SDKDependencyKeys : NSObject {
    @objc
    public static let channel = "channel"
    @objc
    public static let contact = "contact"
    @objc
    public static let push = "push"
    @objc
    public static let remoteData = "remote_data"
    @objc
    public static let config = "config"
    @objc
    public static let dataStore = "dataStore"
    @objc
    public static let analytics = "analytics"
    @objc
    public static let privacyManager = "privacy_manager"
    @objc
    public static let permissionsManager = "permissions_manager"
}

/// NOTE: For internal use only. :nodoc:
enum SDKModuleNames: String, CaseIterable {
    case location = "UALocationSDKModule"
    case messageCenter = "UAMessageCenterSDKModule"
    case automation = "UAAutomationSDKModule"
    case chat = "UAChatSDKModule"
    case preferenceCenter = "UAPreferenceCenterSDKModule"
    case extendedActions = "UAExtendedActionsSDKModule"
    case accengage = "UAAccengageSDKModule"
    case debug = "UADebugSDKModule"
}

/// NOTE: For internal use only. :nodoc:
@objc(UAModuleLoader)
public class ModuleLoader : NSObject {
    
    @objc
    public let components: [Component]
    
    @objc
    public let actionPlists: [String]
    
    @objc
    public init(config: RuntimeConfig,
                dataStore: PreferenceDataStore,
                channel: Channel,
                contact: Contact,
                push: Push,
                remoteData: RemoteDataManager,
                analytics: Analytics,
                privacyManager: PrivacyManager,
                permissionsManager: PermissionsManager) {

        let dependencies: [String : Any] = [
            SDKDependencyKeys.config: config,
            SDKDependencyKeys.dataStore: dataStore,
            SDKDependencyKeys.channel: channel,
            SDKDependencyKeys.contact: contact,
            SDKDependencyKeys.push: push,
            SDKDependencyKeys.remoteData: remoteData,
            SDKDependencyKeys.analytics: analytics,
            SDKDependencyKeys.privacyManager: privacyManager,
            SDKDependencyKeys.permissionsManager: permissionsManager
        ]
        
        let modules = ModuleLoader.loadModules(dependencies)
        self.components = modules.compactMap { $0.components?() }.reduce([], +)
        self.actionPlists = modules.compactMap { $0.actionsPlist?() }
        super.init()
    }
    
    private class func loadModules(_ dependencies: [String : Any]) -> [SDKModule] {
        return SDKModuleNames.allCases.compactMap {
            guard let moduleClass = NSClassFromString($0.rawValue) as? SDKModule.Type else {
                return nil
            }

            AirshipLogger.debug("Loading module \($0)")
            return moduleClass.load(withDependencies: dependencies)
        }
    }
}
