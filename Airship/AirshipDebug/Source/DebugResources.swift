/* Copyright Airship and Contributors */



@objc(UADebugResources)
class DebugResources: NSObject {
    public static func bundle() -> Bundle {
        guard
            let bundlePath = Bundle.main.path(
                forResource: "Airship_AirshipDebug",
                ofType: "bundle"
            )
        else {
            return Bundle(for: DebugResources.self)
        }

        return Bundle(path: bundlePath)!
    }
}

extension String {
    func localized(
        bundle: Bundle = DebugResources.bundle(),
        tableName: String = "AirshipDebug",
        comment: String = ""
    ) -> String {
        return NSLocalizedString(
            self,
            tableName: tableName,
            bundle: bundle,
            comment: comment
        )
    }

    func localizedWithFormat(count: Int) -> String {
        return String.localizedStringWithFormat(localized(), count)
    }
}
