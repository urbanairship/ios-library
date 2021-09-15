
// Copyright Airship and Contributors

import Foundation;

@objc(UAirshipVersion)
public class AirshipVersion : NSObject {
    public static let version = "15.0.0"

    @objc
    public class func get() -> String {
        return version
    }
}