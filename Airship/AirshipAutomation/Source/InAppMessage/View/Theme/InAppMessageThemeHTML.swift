/* Copyright Airship and Contributors */


public import SwiftUI


#if canImport(AirshipCore)
import AirshipCore
#endif


public extension InAppMessageTheme {
    /// Html message theme
    struct HTML: Equatable, Sendable {

        /// Max width in points
        public var maxWidth: CGFloat

        /// Max height in points
        public var maxHeight: CGFloat

        /// If the dismiss icon should be hidden or not. Defaults to `false`
        public var hideDismissIcon: Bool = false

        /// Additional padding
        public var padding: EdgeInsets

        /// Dismiss icon resource name
        public var dismissIconResource: String

        /// Dismiss icon width
        public var dismissIconWidth: CGFloat

        /// Dismiss icon height
        public var dismissIconHeight: CGFloat

        /// Applies a style from a plist to the theme.
        /// - Parameters:
        ///     - plistName: The name of the plist
        ///     - bundle: The plist bundle.
        public mutating func applyPlist(plistName: String, bundle: Bundle? = Bundle.main) throws {
            let overrides = try InAppMessageTheme.decode(
                Overrides.self,
                plistName: plistName,
                bundle: bundle
            )
            self.applyOverrides(overrides)
        }

        mutating func applyPlistIfExists(plistName: String, bundle: Bundle? = Bundle.main) throws {
            let overrides = try InAppMessageTheme.decodeIfExists(
                Overrides.self,
                plistName: plistName,
                bundle: bundle
            )
            self.applyOverrides(overrides)
        }

        mutating func applyOverrides(_ overrides: Overrides?) {
            guard let overrides = overrides else { return }
            self.hideDismissIcon = overrides.hideDismissIcon ?? self.hideDismissIcon
            self.padding.add(overrides.additionalPadding)
            self.dismissIconResource = overrides.dismissIconResource ?? self.dismissIconResource
            self.dismissIconWidth = overrides.dismissIconWidth ?? self.dismissIconWidth
            self.dismissIconHeight = overrides.dismissIconHeight ?? self.dismissIconHeight
            self.maxWidth = overrides.maxWidth ?? self.maxWidth
            self.maxHeight = overrides.maxHeight ?? self.maxHeight
        }

        struct Overrides: Decodable {
            var hideDismissIcon: Bool?
            var additionalPadding: InAppMessageTheme.AdditionalPadding?
            var dismissIconResource: String?
            var dismissIconWidth: CGFloat?
            var dismissIconHeight: CGFloat?
            var maxWidth: CGFloat?
            var maxHeight: CGFloat?
        }

        static let defaultTheme: InAppMessageTheme.HTML = {
            // Default
            var theme = InAppMessageTheme.HTML(
                maxWidth: 420,
                maxHeight: 720,
                padding: EdgeInsets(top: 48, leading: 24, bottom: 48, trailing: 24),
                dismissIconResource: "ua_airship_dismiss",
                dismissIconWidth: 12,
                dismissIconHeight: 12
            )

            /// Overrides
            do {
                try theme.applyPlistIfExists(plistName: "UAInAppMessageHTMLStyle")
            } catch {
                AirshipLogger.error("Unable to apply theme overrides \(error)")
            }
            return theme
        }()
    }
}
