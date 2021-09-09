/* Copyright Airship and Contributors */

import Foundation

@objc(UADebugResources)
class DebugResources: NSObject {
    public static func bundle() -> Bundle {
        guard let bundlePath = Bundle.main.path(forResource: "Airship_AirshipDebug", ofType: "bundle") else {
            return Bundle(for:DebugResources.self);
        };

        return Bundle(path:bundlePath)!
    }
}
