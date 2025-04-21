/* Copyright Airship and Contributors */

import Foundation

class AirshipResources {
    static let bundle: Bundle? = findBundle()

    /// Assumes AirshipResources class and UrbanAirship.string resource always exist in the same bundle
    private static func findBundle() -> Bundle? {
        return Bundle(for: AirshipResources.self)
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
    func airshipLocalizedString(fallback: String? = nil) -> String {
        return AirshipResources.localizedString(key: self) ?? fallback ?? self
    }
}

extension ThomasPropertyOverride where T == String {
    /// Resolves a localized string by localizing both the default value and any overrides.
    @MainActor
    static func resolveLocalized(
        state: ViewState,
        overrides: [ThomasPropertyOverride<String>]?,
        defaultValue: String,
        defaultLocalizedKey: String? = nil
    ) -> String {
        // Localize the default value
        let localizedDefault = defaultLocalizedKey?.airshipLocalizedString(fallback: defaultValue) ?? defaultValue

        // Localize each override's value, if it exists
        let localizedOverrides = overrides?.map { override in
            let localizedValue = override.value?.airshipLocalizedString()
            return ThomasPropertyOverride<String>(
                whenStateMatches: override.whenStateMatches,
                value: localizedValue
            )
        }

        return resolveRequired(
            state: state,
            overrides: localizedOverrides,
            defaultValue: localizedDefault
        )
    }
}
