/* Copyright Airship and Contributors */

import UIKit

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(Airship)
import Airship
#endif

public class AirshipDebug : NSObject {
    @objc public static var deviceInfoViewName = "AirshipDebugDeviceInfo"
    @objc public static let automationViewName = "AirshipDebugAutomation"
    @objc public static let eventsViewName = "AirshipDebugEvents"
    @objc public static let receivedPushesViewName = "AirshipDebugPush"

    @objc public static var tagsViewName = DeviceInfoViewController.tagsViewName

    @objc public class var deviceInfoViewController : UIViewController? {
        get {
            if (_deviceInfoViewController == nil) {
                _deviceInfoViewController = viewControllerForStoryboard(deviceInfoViewName)
            }
            return _deviceInfoViewController
        }
    }
    @objc public class var automationViewController : UIViewController? {
        get {
            if (_automationViewController == nil) {
                _automationViewController = viewControllerForStoryboard(automationViewName)
            }
            return _automationViewController
        }
    }
    @objc public class var eventsViewController : UIViewController? {
        get {
            if (_eventsViewController == nil) {
                _eventsViewController = viewControllerForStoryboard(eventsViewName)
            }
            return _eventsViewController
        }
    }
    
    /**
     * Get the initial view controller for the requested storyboard
     */
    private static func viewControllerForStoryboard(_ storyBoardName : String) -> UIViewController? {
        if let rootViewController = rootViewController {
            return rootViewController.viewControllerForStoryboard(storyBoardName)
        } else {
            return instantiateViewControllerForStoryboard(storyBoardName)
        }
    }
    
    static var _deviceInfoViewController : UIViewController?
    static var _automationViewController : UIViewController?
    static var _eventsViewController : UIViewController?

    static var rootViewController : RootTableViewController?

    /**
     * Provides an initialization point for AirshipDebug components.
     */
    internal static func takeOff(_ analytics: Analytics) {
        // Set data manager as analytics event consumer on AirshipDebug start
        analytics.eventConsumer = EventDataManager.shared
        observePayloadEvents();
    }

    @objc public class func showView(_ launchPathComponents : [String]?) {
        if let rootViewController = rootViewController {
            rootViewController.showView(launchPathComponents)
            return
        }
        
        // no rootViewController in use, so get the view controller
        // from the appropriate storyboard and display it
        guard var pathComponents = launchPathComponents else {
            _ = popToRootViewOfDestination()
            return
        }

        if (pathComponents.isEmpty) {
            _ = popToRootViewOfDestination()
            return
        }

        if (pathComponents[0] == "/") {
            pathComponents.remove(at: 0)
        }
        
        if (pathComponents.count == 0) {
            // just want the base debugkit view
            _ = popToRootViewOfDestination()
            return
        }
        
        // get storyboard name from first segment of deeplink
        let storyBoardName = pathComponents[0]
        pathComponents.remove(at: 0)
        
        // map storyboard name to view controller
        if let viewController = instantiateViewControllerForStoryboard(storyBoardName) {
            if let topController = popToRootViewOfDestination() {
                // set launch path (deep link)
                if let deviceInfoViewController = viewController as? DeviceInfoViewController {
                    deviceInfoViewController.launchPathComponents = pathComponents
                } else if let eventsViewController = viewController as? EventsViewController {
                    eventsViewController.launchPathComponents = pathComponents
                } else if let automationTableViewController = viewController as? AutomationTableViewController {
                    automationTableViewController.launchPathComponents = pathComponents
                }
                
                // display the destination view, that view will deal with any remaining pathComponents
                topController.navigationController?.pushViewController(viewController, animated: true)
            }
        }
    }
    
    fileprivate static func popToRootViewOfDestination() -> UIViewController? {
        if var topController = UIApplication.shared.keyWindow?.rootViewController {
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            
            if let tabBarController = topController as? UITabBarController {
                topController = tabBarController.selectedViewController!
            }
            if let navController = topController as? UINavigationController {
                topController = navController.topViewController!
            }
            
            let topControllerAfterPop = topController.navigationController?.viewControllers[0]
            topController.navigationController?.popToRootViewController(animated: false)
            
            return topControllerAfterPop
        }
        return nil
    }
    
    /**
     * Loads one of the debug storyboards.
     * @param name Name of the storyboard you want loaded, e.g. "DeviceInfo".
     * @return Initial view controller for the instantiated storyboard.
     */
    class func instantiateViewControllerForStoryboard(_ storyBoardName : String) -> UIViewController? {
        // find the bundle containing the storyboard
        var storyboardBundle : Bundle = UADebugResources.bundle();
        if (storyboardBundle.path(forResource: storyBoardName, ofType: "storyboardc") == nil) {
            // if it is not the main bundle, then it should be in the resource bundle
            let resourceBundlePath = storyboardBundle.path(forResource: "AirshipDebugResources", ofType: "bundle")
            if (resourceBundlePath == nil) {
                print("ERROR: storyboard named \(storyBoardName) not found")
                return nil
            }
            storyboardBundle = Bundle.init(path: resourceBundlePath!)!
            if (storyboardBundle.path(forResource: storyBoardName, ofType: "storyboardc") == nil) {
                print("ERROR: storyboard named \(storyBoardName) not found")
                return nil
            }
        }
        
        // get the requested storyboard from the bundle
        let storyboard = UIStoryboard(name: storyBoardName, bundle: storyboardBundle)

        return storyboard.instantiateInitialViewController()
    }

    static func observePayloadEvents() {
        NotificationCenter.default.addObserver(self,
                                               selector:#selector(receivedForegroundNotification(notification:)),
                                               name: Push.ReceivedForegroundNotificationEvent,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector:#selector(receivedBackgroundNotification(notification:)),
                                               name: Push.ReceivedBackgroundNotificationEvent,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector:#selector(receivedNotificationResponse(notification:)),
                                               name: Push.ReceivedNotificationResponseEvent,
                                               object: nil)
    }

    @objc static func receivedForegroundNotification(notification: NSNotification) {
        guard let userInfo = notification.userInfo else {
            return
        }
        savePush(userInfo: userInfo)
    }

    @objc static func receivedBackgroundNotification(notification: NSNotification) {
        guard let userInfo = notification.userInfo else {
            return
        }

        savePush(userInfo: userInfo)
    }

    @objc static func receivedNotificationResponse(notification: NSNotification) {
        guard let response = notification.userInfo?[Push.ReceivedNotificationResponseEventResponseKey] as? UNNotificationResponse else {
            return
        }
        
        let push = response.notification.request.content.userInfo
        savePush(userInfo: push)
    }

    static func savePush(userInfo : [AnyHashable: Any]) {
        guard let pushPayload = try? PushNotification(push: userInfo) else {
            return
        }
        PushDataManager.shared.savePushNotification(pushPayload)
    }
}

// MARK: Extensions for Localization

/**
 * Translate the string using the DebugKit strings file
 */
internal extension String {
    func localized(bundle: Bundle = UADebugResources.bundle(), tableName: String = "AirshipDebug", comment: String = "") -> String {
        return NSLocalizedString(self, tableName: tableName, bundle: bundle, comment: comment)
    }

    func localizedWithFormat(count:Int) -> String {
        return String.localizedStringWithFormat(localized(), count)
    }
}

/**
 * Adds IBInspectable to UILabel for use in storyboards.
 *
 * Designer can enter a localization key in the storyboard attributes
 * inspector for the UILabel. This key will be used to localize the
 * UILabel's text when the storyboard is loaded.
 */
internal extension UILabel {
    @IBInspectable var keyForLocalization: String? {
        // Don't need to ever get the key.
        get { return nil }
        // When the key is set by the storyboard, localize it
        // and set the localized text as the text of the UILabel
        set(key) {
            text = key?.localized()
        }
    }
}

/**
 * Adds IBInspectable to UINavigationItem for use in storyboards.
 *
 * Designer can enter a localization key in the storyboard attributes
 * inspector for the UINavigationItem. This key will be used to localize the
 * UINavigationItem's title when the storyboard is loaded.
 */
internal extension UINavigationItem {
    @IBInspectable var keyForLocalization: String? {
        // Don't need to ever get the key.
        get { return nil }
        set(key) {
            // When the key is set by the storyboard, localize it
            // and set the localized text as the title of the UINavigationItem
            title = key?.localized()
        }
    }
}

/**
 * Adds IBInspectable to UITextField for use in storyboards.
 *
 * Designer can enter a localization key in the storyboard attributes
 * inspector for the UITextField. This key will be used to localize the
 * UITextField's placeholder when the storyboard is loaded.
 */
internal extension UITextField {
    @IBInspectable var keyForLocalization: String? {
        // Don't need to ever get the key.
        get { return nil }
        set(key) {
            // When the key is set by the storyboard, localize it
            // and set the localized text as the placeholder of the UITextField
            placeholder = key?.localized()
        }
    }
}
