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
     *   - preferenceCenterID: The preference center ID.
     *   - Returns: `true` if the preference center was opened, otherwise `false` to fallback to OOTB UI.
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
    
    var preferenceCenterWindow: UIWindow?
    
    /**
     * Open delegate.
     *
     * If set, the delegate will be called instead of launching the OOTB preference center screen.
     */
    @objc
    public weak var openDelegate: PreferenceCenterOpenDelegate?
    
    private let dataStore: PreferenceDataStore
    private let privacyManager: PrivacyManager
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
    
    init(dataStore: PreferenceDataStore, privacyManager: PrivacyManager, remoteDataProvider: RemoteDataProvider) {
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
     *   - preferenceCenterID: The preference center ID.
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
        
        let preferenceCenterVC = PreferenceCenterViewController(identifier: preferenceCenterID)
        
        preferenceCenterVC.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismiss))
        
        preferenceCenterVC.style = style
        
        viewController = preferenceCenterVC
    
        if let window =  Utils.presentInNewWindow(createNavigationViewController()) {
            self.preferenceCenterWindow = window
            AirshipLogger.trace("Presented preference center view controller: \(preferenceCenterVC.description)")
        }
    }
    
    private func createNavigationViewController() -> UINavigationController {
        let navController = UINavigationController(nibName: nil, bundle: nil)
        navController.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
        navController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        
        var titleTextAttributes: [NSAttributedString.Key : Any] = [:]
        titleTextAttributes[.font] = style?.titleFont
        titleTextAttributes[.foregroundColor] = style?.titleColor
        
        navController.navigationBar.tintColor = style?.tintColor
        navController.navigationBar.barTintColor = style?.navigationBarColor
        if (!titleTextAttributes.isEmpty) {
            navController.navigationBar.titleTextAttributes = titleTextAttributes
        }
        
        // Customizing our navigation bar
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = style?.navigationBarColor
            if (!titleTextAttributes.isEmpty) {
                appearance.titleTextAttributes = titleTextAttributes
            }
            navController.navigationBar.standardAppearance = appearance
            navController.navigationBar.scrollEdgeAppearance = appearance
        }
        
        if let vc = viewController {
            navController.pushViewController(vc, animated: false)
        }
        return navController
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
        preferenceCenterWindow = nil
    }
    
    /**
     * Returns the configuration of the Preference Center with the given ID trough a callback method.
     * - Parameters:
     *   - preferenceCenterID: The preference center ID.
     *   - completionHandler: The completion handler that will receive the requested PreferenceCenterConfig
     */
    @objc(configForPreferenceCenterID:completionHandler:)
    @discardableResult
    public func config(preferenceCenterID: String, completionHandler: @escaping (PreferenceCenterConfig?) -> ()) -> Disposable {
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
