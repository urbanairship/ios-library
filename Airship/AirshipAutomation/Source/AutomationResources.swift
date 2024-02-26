/* Copyright Airship and Contributors */

import Foundation

class AutomationResources {
    static let bundle = findBundle()
    
    private class func findBundle() -> Bundle {
        
        let mainBundle = Bundle.main
        let sourceBundle = Bundle(for: AutomationResources.self)
        
        // SPM
        if let path = mainBundle.path(
            forResource: "Airship_AirshipAutomation",
            ofType: "bundle"
        ) {
            if let bundle = Bundle(path: path) {
                return bundle
            }
        }
        
        // Cocoapods (static)
        if let path = mainBundle.path(
            forResource: "AirshipAutomationResources",
            ofType: "bundle"
        ) {
            if let bundle = Bundle(path: path) {
                return bundle
            }
        }
        
        // Cocoapods (framework)
        if let path = sourceBundle.path(
            forResource: "AirshipAutomationResources",
            ofType: "bundle"
        ) {
            if let bundle = Bundle(path: path) {
                return bundle
            }
        }
        
        // Fallback to source
        return sourceBundle
    }
}
