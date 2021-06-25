
// Copyright Airship and Contributors

import Foundation;

public class UAirshipVersion : NSObject {
    public static let version = "14.5.0"

    @objc
    public class func get() -> String {
        return version
    }
}
