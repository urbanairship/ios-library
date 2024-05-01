/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct FullScreenTheme: Equatable {
    var additionalPadding: EdgeInsets
    var headerTheme: TextTheme
    var bodyTheme: TextTheme
    var mediaTheme: MediaTheme
    var buttonTheme: ButtonTheme
    var dismissIconResource: String

    /// Used for testing
    init(plistName: String,
         bundle: Bundle? = Bundle.main) {
        let overrides = FullScreenThemeOverride(plistName: plistName, bundle: bundle)
        self.init(themeOverride: overrides)
    }

    init(additionalPadding: EdgeInsets,
         headerTheme: TextTheme,
         bodyTheme: TextTheme,
         mediaTheme: MediaTheme,
         buttonTheme: ButtonTheme,
         dismissIconResource: String) {
        self.additionalPadding = additionalPadding
        self.headerTheme = headerTheme
        self.bodyTheme = bodyTheme
        self.mediaTheme = mediaTheme
        self.buttonTheme = buttonTheme
        self.dismissIconResource = dismissIconResource
    }

    init(themeOverride:FullScreenThemeOverride? = FullScreenThemeOverride(plistName: Self.defaultPlistName, bundle: Bundle.main), defaultValues:FullScreenTheme = Self.defaultValues) {
        self.additionalPadding = themeOverride?.additionalPadding
            .map { EdgeInsets(themeOverride: $0, defaults: defaultValues.additionalPadding) }
        ?? defaultValues.additionalPadding

        self.headerTheme = themeOverride?.headerTheme
            .map { TextTheme(themeOverride: $0, defaults: defaultValues.headerTheme) }
        ?? defaultValues.headerTheme

        self.bodyTheme = themeOverride?.bodyTheme
            .map { TextTheme(themeOverride: $0, defaults: defaultValues.bodyTheme) }
        ?? defaultValues.bodyTheme

        self.mediaTheme = themeOverride?.mediaTheme
            .map { MediaTheme(themeOverride: $0, defaults: defaultValues.mediaTheme) }
        ?? defaultValues.mediaTheme

        self.buttonTheme = themeOverride?.buttonTheme
            .map { ButtonTheme(themeOverride: $0, defaults: Self.defaultValues.buttonTheme) }
        ?? defaultValues.buttonTheme

        self.dismissIconResource = themeOverride?.dismissIconResource
        ?? defaultValues.dismissIconResource

    }
}

struct FullScreenThemeOverride: Decodable, PlistLoadable {
    var additionalPadding: EdgeInsetsThemeOverride?
    var headerTheme: TextThemeOverride?
    var bodyTheme: TextThemeOverride?
    var mediaTheme: MediaThemeOverride?
    var buttonTheme: ButtonThemeOverride?
    var dismissIconResource: String?

    enum CodingKeys: String, CodingKey {
        case additionalPadding = "additionalPadding"
        case headerTheme = "headerStyle"
        case bodyTheme = "bodyStyle"
        case mediaTheme = "mediaStyle"
        case buttonTheme = "buttonStyle"
        case dismissIconResource = "dismissIconResource"
    }

    init?() {
        self.init(plistName: FullScreenTheme.defaultPlistName)
    }
}
