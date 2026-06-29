/* Copyright Airship and Contributors */

import Foundation

/// Resolves localized strings for a Thomas layout. Host-provided so the renderer doesn't reach into
/// a particular resource bundle; the SDK wires up a default that reads Airship's resources.
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public protocol ThomasLocalizer: Sendable {
    /// Resolves a localized string for the given key, or `nil` if there's no entry.
    func localizedString(key: String) -> String?
}

extension ThomasLocalizer {
    /// Resolves a localized string for the given key, falling back to `fallback` when missing.
    func localizedString(key: String, fallback: String) -> String {
        localizedString(key: key) ?? fallback
    }

    /// Resolves the first available localized string from a `Localized` ref set, else its fallback.
    func resolveLocalized(_ localized: ThomasAccessibleInfo.Localized) -> String {
        if let refs = localized.refs {
            for ref in refs {
                if let string = localizedString(key: ref) {
                    return string
                }
            }
        } else if let ref = localized.ref {
            if let string = localizedString(key: ref) {
                return string
            }
        }

        return localized.fallback
    }

    /// Resolves the content description for an accessible element, preferring an explicit value
    /// over a localized lookup.
    func resolveContentDescription(for accessible: ThomasAccessibleInfo) -> String? {
        if let contentDescription = accessible.contentDescription {
            return contentDescription
        }

        guard let localized = accessible.localizedContentDescription else {
            return nil
        }

        return resolveLocalized(localized)
    }
}
