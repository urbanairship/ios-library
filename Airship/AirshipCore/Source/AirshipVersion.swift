
// Copyright Airship and Contributors

import Foundation;

@objc(UAirshipVersion)
public class AirshipVersion : NSObject {
    public static let version = "16.10.3"

    @objc
    public class func get() -> String {
        return version
    }
}
