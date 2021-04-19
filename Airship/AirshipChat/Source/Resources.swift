/* Copyright Airship and Contributors */

import Foundation

@available(iOS 13.0, *)
@objc(UAChatResources)
class Resources : NSObject {
    static func bundle() -> Bundle? {
        let mainBundle = Bundle.main
        let path = mainBundle.path(forResource: "Airship_AirshipChat", ofType: "bundle") ?? ""
        return Bundle(path: path) != nil ? Bundle(path: path) : Bundle(for: Self.self)
    }
}
