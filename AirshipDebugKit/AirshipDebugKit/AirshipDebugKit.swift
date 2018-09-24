/* Copyright 2018 Urban Airship and Contributors */

import UIKit

public class AirshipDebugKit : NSObject {
    /**
     * Loads one of the debug storyboards.
     * @param name Name of the storyboard you want loaded, e.g. "DeviceInfo".
     * @return Initial view controller for the instantiated storyboard.
     */
    @objc public class func instantiateStoryboard(_ name : String) -> UIViewController? {
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
