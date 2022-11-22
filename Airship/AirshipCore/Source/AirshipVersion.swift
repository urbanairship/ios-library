
// Copyright Airship and Contributors

import Foundation;

@objc(UAirshipVersion)
public class AirshipVersion : NSObject {
    public static let version = "16.10.4"

    @objc
    public class func get() -> String {
        return version
    }
}
