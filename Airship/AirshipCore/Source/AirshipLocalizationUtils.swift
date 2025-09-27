/* Copyright Airship and Contributors */

import Foundation

/// - NOTE: Internal use only :nodoc:
public final class AirshipLocalizationUtils {

    private static func sanitizedLocalizedString(
        _ localizedString: String,
        withTable table: String?,
        primaryBundle: Bundle,
        secondaryBundle: Bundle,
        tertiaryBundle: Bundle?
    ) -> String? {

        var string: String?

        /// This "empty" string has a space in it, so as not to be treated as equivalent to nil by the NSBundle method
        let missing = " "

        string = NSLocalizedString(
            localizedString,
            tableName: table,
            bundle: primaryBundle,
            value: missing,
            comment: ""
        )

        if string == nil || (string == missing) {
            string = NSLocalizedString(
                localizedString,
                tableName: table,
                bundle: secondaryBundle,
                value: missing,
                comment: ""
            )
        }

        if string == nil || (string == missing) {
            string = NSLocalizedString(
                localizedString,
                tableName: table,
                bundle: tertiaryBundle!,
                value: missing,
                comment: ""
            )
        }

        if string == nil || (string == missing) {
            return nil
        }

        return string
    }

    public static func localizedString(
        _ string: String,
        withTable table: String,
        moduleBundle: Bundle?,
    ) -> String? {

        let mainBundle = Bundle.main
        let coreBundle = AirshipCoreResources.bundle

        return sanitizedLocalizedString(
            string,
            withTable: table,
            primaryBundle: mainBundle,
            secondaryBundle: coreBundle,
            tertiaryBundle: moduleBundle
        )
    }
}
