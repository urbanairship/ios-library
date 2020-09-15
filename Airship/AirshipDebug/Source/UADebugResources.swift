/* Copyright Airship and Contributors */

import Foundation

class UADebugResources: NSObject {
    public static func bundle() -> Bundle {
        guard let bundlePath = Bundle.main.path(forResource: "Airship_AirshipDebug", ofType: "bundle") else {
            return Bundle(for:UADebugResources.self);
        };

        return Bundle(path:bundlePath)!
    }
}
