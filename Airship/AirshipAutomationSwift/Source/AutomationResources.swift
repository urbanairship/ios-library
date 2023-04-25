/* Copyright Airship and Contributors */

class AutomationResources: NSObject {
    
    public static let bundle = findBundle()
    
    private class func findBundle() -> Bundle {
        
        let mainBundle = Bundle.main
        let sourceBundle = Bundle(for: AutomationResources.self)
        
        // SPM
        if let path = mainBundle.path(
            forResource: "Airship_AirshipAutomationSwift",
            ofType: "bundle"
        ) {
            if let bundle = Bundle(path: path) {
                return bundle
            }
        }
        
        // Cocopaods (static)
        if let path = mainBundle.path(
            forResource: "AirshipAutomationSwiftResources",
            ofType: "bundle"
        ) {
            if let bundle = Bundle(path: path) {
                return bundle
            }
        }
        
        // Cocopaods (framework)
        if let path = sourceBundle.path(
            forResource: "AirshipAutomationSwiftResources",
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
