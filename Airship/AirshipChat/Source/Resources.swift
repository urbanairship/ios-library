/* Copyright Airship and Contributors */

import Foundation

@available(iOS 13.0, *)
@objc(UAChatResources)
public class ChatResources : NSObject {
    static func bundle() -> Bundle? {
        let mainBundle = Bundle.main
        let path = mainBundle.path(forResource: "Airship_AirshipChat", ofType: "bundle") ?? ""
        return Bundle(path: path) ?? Bundle(for: Self.self)
    }
}
