/* Copyright Airship and Contributors */

import Foundation
public import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

public extension InAppMessageTheme {


    /// Banner in-app message theme
    struct Banner: Equatable {

        /// Max width
        public var maxWidth: CGFloat

        /// Padding
        public var padding: EdgeInsets

        /// Tap opacity when the banner is tappable
        public var tapOpacity: CGFloat

        /// Shadow theme
        public var shadow: InAppMessageTheme.Shadow

        /// Header theme
        public var header: InAppMessageTheme.Text

        /// Body theme
        public var body: InAppMessageTheme.Text

        // Media theme
        public var media: InAppMessageTheme.Media

        /// Button theme
        public var buttons:  InAppMessageTheme.Button

        /// Default plist file for overrides
        public static let defaultPlistName: String = "UAInAppMessageBannerStyle"

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
            self.padding.add(overrides.additionalPadding)
            self.maxWidth = overrides.maxWidth ?? self.maxWidth
            self.tapOpacity = overrides.tapOpacity ?? tapOpacity
            self.shadow.applyOverrides(overrides.shadowTheme)
            self.header.applyOverrides(overrides.headerTheme)
            self.body.applyOverrides(overrides.bodyTheme)
            self.media.applyOverrides(overrides.mediaTheme)
            self.buttons.applyOverrides(overrides.buttonTheme)
        }

        struct Overrides: Decodable {
            var additionalPadding: InAppMessageTheme.AdditionalPadding?
            var maxWidth: CGFloat?
            var tapOpacity: CGFloat?
            var shadowTheme: InAppMessageTheme.Shadow.Overrides?
            var headerTheme: InAppMessageTheme.Text.Overrides?
            var bodyTheme: InAppMessageTheme.Text.Overrides?
            var mediaTheme: InAppMessageTheme.Media.Overrides?
            var buttonTheme: InAppMessageTheme.Button.Overrides?

            enum CodingKeys: String, CodingKey {
                case additionalPadding = "additionalPadding"
                case maxWidth = "maxWidth"
                case tapOpacity = "tapOpacity"
                case shadowTheme = "shadowStyle"
                case headerTheme = "headerStyle"
                case bodyTheme = "bodyStyle"
                case mediaTheme = "mediaStyle"
                case buttonTheme = "buttonStyle"
            }
        }

        static let defaultTheme: InAppMessageTheme.Banner = {
            // Default
            var theme = InAppMessageTheme.Banner(
                maxWidth: 480,
                padding: EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24),
                tapOpacity: 0.7,
                shadow: InAppMessageTheme.Shadow(
                    radius: 5,
                    xOffset: 0,
                    yOffset: 0,
                    color: Color.black.opacity(0.33)
                ),
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
                    padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
                ),
                buttons: InAppMessageTheme.Button(
                    height: 33,
                    stackedSpacing: 24,
                    separatedSpacing: 16,
                    padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
                )
            )

            /// Overrides
            do {
                try theme.applyPlistIfExists(plistName: "UAInAppMessageBannerStyle")
            } catch {
                AirshipLogger.error("Unable to apply theme overrides \(error)")
            }
            return theme
        }()
    }

}
