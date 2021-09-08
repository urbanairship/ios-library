/* Copyright Airship and Contributors */

import Foundation;

#if canImport(AirshipCore)
import AirshipCore
#endif

/**
 * Open delegate.
 */
@objc(UAPreferenceCenterOpenDelegate)
public protocol PreferenceCenterOpenDelegate {

    /**
     * Opens the Preference Center with the given ID.
     * - Parameters:
     *  - preferenceCenterID: The preference center ID.
     *  - Returns: `true` if the preference center was opened, otherwise `false` to fallback to OOTB UI.
     */
    @objc
    func openPreferenceCenter(_ preferenceCenterID: String) -> Bool
}

/**
 * Airship PreferenceCenter module.
 */
@objc(UAPreferenceCenter)
public class PreferenceCenter : NSObject, Component {
    
    /// The shared PreferenceCenter instance.
    @objc
    public static var shared: PreferenceCenter {
        return Airship.requireComponent(ofType: PreferenceCenter.self)
    }
    
    private static let payloadType = "preference_forms"
    private static let preferenceFormsKey = "preference_forms"
    
    /**
     * Open delegate.
     *
     * If set, the delegate will be called instead of launching the OOTB preference center screen.
     */
    @objc
    public weak var openDelegate: PreferenceCenterOpenDelegate?
    
    private let dataStore: UAPreferenceDataStore
    private let privacyManager: UAPrivacyManager
    private let remoteDataProvider: RemoteDataProvider
    
    private var viewController : UIViewController?
    
    /**
     * Preference center style
     */
    @objc
    public var style: PreferenceCenterStyle?
    
    private let disableHelper: ComponentDisableHelper
        
    // NOTE: For internal use only. :nodoc:
    public var isComponentEnabled: Bool {
        get {
            return disableHelper.enabled
        }
        set {
            disableHelper.enabled = newValue
        }
    }
    
    init(dataStore: UAPreferenceDataStore, privacyManager: UAPrivacyManager, remoteDataProvider: RemoteDataProvider) {
        self.dataStore = dataStore
        self.privacyManager = privacyManager
        self.remoteDataProvider = remoteDataProvider
        self.style = PreferenceCenterStyle(file: "AirshipPreferenceCenterStyle")
        self.disableHelper = ComponentDisableHelper(dataStore: dataStore, className: "PreferenceCenter")
        super.init()
        AirshipLogger.info("PreferenceCenter initialized")
    }
    
    /**
     * Opens the Preference Center with the given ID.
     * - Parameters:
     *  - preferenceCenterID: The preference center ID.
     */
    @objc(openPreferenceCenter:)
    public func open(_ preferenceCenterID: String) {
        if (self.openDelegate?.openPreferenceCenter(preferenceCenterID) == true) {
            AirshipLogger.trace("Preference center \(preferenceCenterID) opened through delegate")
        } else {
            AirshipLogger.trace("Launching OOTB preference center")
            openDefaultPreferenceCenter(preferenceCenterID: preferenceCenterID)
        }
    }
    
    private func openDefaultPreferenceCenter(preferenceCenterID: String) {
        guard viewController == nil else {
            AirshipLogger.debug("Already displaying preference center: \(self.viewController!.description)")
            return
        }

        AirshipLogger.debug("Opening default preference center UI")
    
        let preferenceCenterVC = PreferenceCenterViewController.init(identifier:preferenceCenterID, nibName: "PreferenceCenterViewController", bundle: PreferenceCenterResources.bundle())

        preferenceCenterVC.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismiss))
       
        preferenceCenterVC.style = style
        
        viewController = preferenceCenterVC
        
        let navController = UINavigationController(nibName: nil, bundle: nil)
        navController.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
        navController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        
        navController.navigationBar.tintColor = style?.tintColor
        navController.navigationBar.barTintColor = style?.navigationBarColor
        
        navController.pushViewController(preferenceCenterVC, animated: false)
        
        UAUtils.topController()?.present(navController, animated: true, completion: {
            AirshipLogger.trace("Presented preference center view controller: \(preferenceCenterVC.description)")
        })
    }

    @objc
    private func dismiss(sender: Any) {
        if let vc = viewController {
            vc.dismiss(animated: true) {
                AirshipLogger.trace("Dismissed preference center view controller: \(vc.description)")
                self.viewController = nil
            }
        } else {
            AirshipLogger.debug("Preference center already dismissed")
        }
    }
    
    /**
     * Returns the configuration of the Preference Center with the given ID trough a callback method.
     * - Parameters:
     *  - preferenceCenterID: The preference center ID.
     *  - completionHandlerThe completion handler that will receive the requested PreferenceCenterConfig
     */
    @objc(configForPreferenceCenterID:completionHandler:)
    @discardableResult
    public func config(preferenceCenterID: String, completionHandler: @escaping (PreferenceCenterConfig?) -> ()) -> UADisposable {
        return self.remoteDataProvider.subscribe(types: [PreferenceCenter.payloadType]) { payloads in
            
            guard let preferences = payloads.first?.data[PreferenceCenter.preferenceFormsKey] as? [[AnyHashable : Any]] else {
                completionHandler(nil)
                return
            }
            
            let responses : [PrefrenceCenterResponse] = preferences.compactMap {
                do {
                    return try PreferenceCenterDecoder.decodeConfig(object: $0)
                } catch {
                    AirshipLogger.error("Failed to parse preference center config \(error)")
                    return nil
                }
            }
            
            let config = responses.first { $0.config.identifier == preferenceCenterID }?.config
            completionHandler(config)
        }
    }
    
    // NOTE: For internal use only. :nodoc:
    public func deepLink(_ deepLink: URL) -> Bool {
        guard deepLink.scheme == Airship.deepLinkScheme,
              deepLink.host == "preferences",
              deepLink.pathComponents.count == 2 else {
            return false
        }
        
        let preferenceCenterID = deepLink.pathComponents[1]
        self.open(preferenceCenterID)
        return true
    }
}
