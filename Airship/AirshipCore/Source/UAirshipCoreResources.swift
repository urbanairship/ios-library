/* Copyright Airship and Contributors */

@objc
public class UAirshipCoreResources : NSObject {
    @objc
    public class func bundle() -> Bundle? {
        let bundle = Bundle(
            path: Bundle.main.path(
                forResource: "Airship_AirshipCore",
                ofType: "bundle") ?? "")

        return bundle ?? Bundle(for: UAirshipCoreResources.self)
    }
}
