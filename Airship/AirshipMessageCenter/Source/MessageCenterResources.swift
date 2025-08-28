/* Copyright Airship and Contributors */


#if canImport(AirshipCore)
import AirshipCore
#endif

class MessageCenterResources {

    static let bundle: Bundle? = findBundle()

    private static func findBundle() -> Bundle? {
        let mainBundle = Bundle.main
        let sourceBundle = Bundle(for: MessageCenterResources.self)

        // SPM
        var bundle = Bundle(
            path: mainBundle.path(
                forResource: "Airship_AirshipMessageCenter",
                ofType: "bundle"
            ) ?? ""
        )
        // Cocopaods (static)
        bundle =
            bundle
            ?? Bundle(
                path: mainBundle.path(
                    forResource: "AirshipMessageCenterResources",
                    ofType: "bundle"
                ) ?? ""
            )
        // Cocopaods (framework)
        bundle =
            bundle
            ?? Bundle(
                path: sourceBundle.path(
                    forResource: "AirshipMessageCenterResources",
                    ofType: "bundle"
                ) ?? ""
            )
        return bundle ?? sourceBundle
    }

    public static func localizedString(key: String) -> String? {
        return AirshipLocalizationUtils.localizedString(
            key,
            withTable: "UrbanAirship",
            moduleBundle: bundle
        )
    }

}

extension String {
    var messageCenterLocalizedString: String {
        return MessageCenterResources.localizedString(key: self) ?? self
    }
}
