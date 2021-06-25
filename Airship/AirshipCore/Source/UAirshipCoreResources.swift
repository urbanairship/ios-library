/* Copyright Airship and Contributors */

@objc
public class UAirshipCoreResources : NSObject {

    @objc
    public static let bundle = findBundle()

    private class func findBundle() -> Bundle {
        let mainBundle =  Bundle.main
        let sourceBundle = Bundle(for: UAirshipCoreResources.self)

        // SPM
        if let path = mainBundle.path(forResource:"Airship_AirshipCore", ofType: "bundle") {
            if let bundle = Bundle(path: path) {
                return bundle
            }
        }

        // Cocopaods (static)
        if let path = mainBundle.path(forResource:"AirshipCoreResources", ofType: "bundle") {
            if let bundle = Bundle(path: path) {
                return bundle
            }
        }

        // Cocopaods (framework)
        if let path = sourceBundle.path(forResource:"AirshipCoreResources", ofType: "bundle") {
            if let bundle = Bundle(path: path) {
                return bundle
            }
        }

        // Fallback to source
        return sourceBundle
    }
}
