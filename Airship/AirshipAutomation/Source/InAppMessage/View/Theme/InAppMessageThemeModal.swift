/* Copyright Airship and Contributors */

import Foundation
public import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

public extension InAppMessageTheme {

    /// Modal in-app message theme
    struct Modal: Equatable, Sendable {

        /// Max width
        public var maxWidth: CGFloat

        /// Max height
        public var maxHeight: CGFloat

        /// Padding
        public var padding: EdgeInsets

        /// Header theme
        public var header: InAppMessageTheme.Text

        /// Body theme
        public var body: InAppMessageTheme.Text

        // Media theme
        public var media: InAppMessageTheme.Media

        /// Button theme
        public var buttons:  InAppMessageTheme.Button

        /// Dismiss icon resource name
        public var dismissIconResource:  String

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
            self.maxWidth = overrides.maxWidth ?? self.maxWidth
            self.maxHeight = overrides.maxHeight ?? self.maxHeight
            self.padding.add(overrides.additionalPadding)
            self.header.applyOverrides(overrides.headerTheme)
            self.body.applyOverrides(overrides.bodyTheme)
            self.media.applyOverrides(overrides.mediaTheme)
            self.buttons.applyOverrides(overrides.buttonTheme)
            self.dismissIconResource = overrides.dismissIconResource ?? self.dismissIconResource
            self.dismissIconWidth = overrides.dismissIconWidth ?? self.dismissIconWidth
            self.dismissIconHeight = overrides.dismissIconHeight ?? self.dismissIconHeight
        }

        struct Overrides: Decodable {
            var additionalPadding: InAppMessageTheme.AdditionalPadding?
            var headerTheme: InAppMessageTheme.Text.Overrides?
            var bodyTheme: InAppMessageTheme.Text.Overrides?
            var mediaTheme: InAppMessageTheme.Media.Overrides?
            var buttonTheme: InAppMessageTheme.Button.Overrides?
            var dismissIconResource: String?
            var dismissIconWidth: CGFloat?
            var dismissIconHeight: CGFloat?
            var maxWidth: CGFloat?
            var maxHeight: CGFloat?

            enum CodingKeys: String, CodingKey {
                case additionalPadding = "additionalPadding"
                case headerTheme = "headerStyle"
                case bodyTheme = "bodyStyle"
                case mediaTheme = "mediaStyle"
                case buttonTheme = "buttonStyle"
                case dismissIconResource = "dismissIconResource"
                case dismissIconWidth = "dismissIconWidth"
                case dismissIconHeight = "dismissIconHeight"
                case maxWidth = "maxWidth"
                case maxHeight = "maxHeight"
            }
        }

        static let defaultTheme: InAppMessageTheme.Modal = {
            // Default
            var theme = InAppMessageTheme.Modal(
                maxWidth: 420,
                maxHeight: 720,
                padding: EdgeInsets(top: 48, leading: 24, bottom: 48, trailing: 24),
                header: InAppMessageTheme.Text(
                    letterSpacing: 0,
                    lineSpacing: 0,
                    padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
                ),
                body: InAppMessageTheme.Text(
                    letterSpacing: 0,
                    lineSpacing: 0,
                    padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
                ),
                media: InAppMessageTheme.Media(
                    padding: EdgeInsets(top: 0, leading: -24, bottom: 0, trailing: -24)
                ),
                buttons: InAppMessageTheme.Button(
                    height: 33,
                    stackedSpacing: 24,
                    separatedSpacing: 16,
                    padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
                ),
                dismissIconResource: "ua_airship_dismiss",
                dismissIconWidth: 12,
                dismissIconHeight: 12
            )

            /// Overrides
            do {
                try theme.applyPlistIfExists(plistName: "UAInAppMessageModalStyle")
            } catch {
                AirshipLogger.error("Unable to apply theme overrides \(error)")
            }
            return theme
        }()
    }
}
