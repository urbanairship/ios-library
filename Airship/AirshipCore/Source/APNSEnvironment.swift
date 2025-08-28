/* Copyright Airship and Contributors */



struct APNSEnvironment {

#if !targetEnvironment(macCatalyst)
    private static let defaultProfilePath: String? = Bundle.main.path(
            forResource: "embedded",
            ofType: "mobileprovision"
        )
#else
    private static let defaultProfilePath: String? = URL(
            fileURLWithPath: URL(
                fileURLWithPath: Bundle.main.resourcePath ?? ""
            )
            .deletingLastPathComponent().path
        )
        .appendingPathComponent("embedded.provisionprofile").path
#endif

    public static func isProduction() throws -> Bool {
        return try isProduction(self.defaultProfilePath)
    }

    public static func isProduction(
        _ profilePath: String?
    ) throws -> Bool {
        guard
            let path = profilePath,
            let embeddedProfile: String = try? String(
                contentsOfFile: path,
                encoding: .isoLatin1
            )
        else {
            throw AirshipErrors.error("No mobile provisioning profile found \(profilePath ?? "null")")
        }

        let scanner = Scanner(string: embeddedProfile)

        _ = scanner.scanUpToString("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")

        guard let extractedPlist = scanner.scanUpToString("</plist>"),
            let plistData = extractedPlist.appending("</plist>")
                .data(using: .utf8),
            let plistDict = try? PropertyListSerialization.propertyList(
                from: plistData,
                options: [],
                format: nil
            ) as? [AnyHashable: Any]
        else {
            throw AirshipErrors.error("Unable to read provisioning profile \(path)")
        }

        guard
            let entitlements = plistDict["Entitlements"] as? [AnyHashable: Any]
        else {
            throw AirshipErrors.error("Unable to read provisioning profile \(path). No entitlements.")
        }

        guard let apsEnvironment = entitlements["aps-environment"] as? String else  {
            throw AirshipErrors.error("aps-environment value is not set \(path), ensure that the app is properly provisioned for push.")
        }

        switch(apsEnvironment) {
        case "production": return true
        case "development": return false
        default: throw AirshipErrors.error("Unexpected aps-environment \(apsEnvironment)")
        }
    }
}


