/* Copyright 2018 Urban Airship and Contributors */

import UIKit

public class AirshipDebugKit : NSObject {
    @objc public static var deviceInfoViewController : UIViewController? = instantiateStoryboard("DeviceInfo")
    @objc public static var automationViewController : UIViewController? = instantiateStoryboard("Automation")
    
    /**
     * Loads one of the debug storyboards.
     * @param name Name of the storyboard you want loaded, e.g. "DeviceInfo".
     * @return Initial view controller for the instantiated storyboard.
     */
    class func instantiateStoryboard(_ name : String) -> UIViewController? {
        // find the bundle containing the storyboard
        var storyboardBundle : Bundle = Bundle(for: self)
        if (storyboardBundle.path(forResource: name, ofType: "storyboardc") == nil) {
            // if it is not the main bundle, then it should be in the resource bundle
            let resourceBundlePath = storyboardBundle.path(forResource: "AirshipDebugResources", ofType: "bundle")
            storyboardBundle = Bundle.init(path: resourceBundlePath!)!
        }
        
        // get the requested storyboard from the bundle
        let storyboard = UIStoryboard(name: name, bundle: storyboardBundle)

        return storyboard.instantiateViewController(withIdentifier: "InitialController")
    }
}

/**
 * Extensions for Localization
 */

internal extension String {
    func localized(bundle: Bundle = Bundle(for: AirshipDebugKit.self), tableName: String = "Localizable") -> String {
        return NSLocalizedString(self, tableName: tableName, bundle: bundle, comment: "")
    }
}

internal extension UILabel {
    @IBInspectable var keyForLocalization: String? {
        get { return nil }
        set(key) {
            text = key?.localized()
        }
    }
}

internal extension UINavigationItem {
    @IBInspectable var keyForLocalization: String? {
        get { return nil }
        set(key) {
            title = key?.localized()
        }
    }
}

