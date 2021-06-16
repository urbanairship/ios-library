/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#elseif !COCOAPODS && canImport(Airship)
import Airship
#endif

/**
 * Resources for AirshipChat.
 */
@available(iOS 13.0, *)
@objc(UAChatResources)
public class ChatResources : NSObject {

    /**
     * Resource bundle for AirshipChat.
     * @return The chat bundle.
     */
    @objc
    public static func bundle() -> Bundle? {
        let mainBundle = Bundle.main
        let sourceBundle = Bundle(for: Self.self)

        let path = mainBundle.path(forResource: "Airship_AirshipChat", ofType: "bundle") ??
                   mainBundle.path(forResource: "AirshipChatResources", ofType: "bundle") ??
                   sourceBundle.path(forResource: "AirshipChatResources", ofType: "bundle") ?? ""

        return Bundle(path: path) ?? sourceBundle
    }

    public static func localizedString(key: String) -> String? {
        return key.localizedString(withTable:"UrbanAirship", moduleBundle:bundle())
    }
}
