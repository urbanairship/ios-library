/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct HTMLTheme: Equatable {
    var hideDismissIcon: Bool
    var additionalPadding: EdgeInsets
    var dismissIconResource: String

    var maxWidth: Int
    var maxHeight: Int

    /// Used for testing
    init(plistName: String,
         bundle: Bundle? = Bundle.main) {
        let overrides = HTMLThemeOverride(plistName: plistName, bundle: bundle)
        self.init(themeOverride: overrides)
    }

    init(hideDismissIcon: Bool,
         additionalPadding: EdgeInsets,
         dismissIconResource: String,
         maxWidth: Int,
         maxHeight: Int) {
        self.hideDismissIcon = hideDismissIcon
        self.additionalPadding = additionalPadding
        self.dismissIconResource = dismissIconResource
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
    }

    init(themeOverride:HTMLThemeOverride? = HTMLThemeOverride(plistName: Self.defaultPlistName, bundle: Bundle.main),
         defaultValues:HTMLTheme = Self.defaultValues) {
        self.hideDismissIcon = themeOverride?.hideDismissIcon
        ?? defaultValues.hideDismissIcon

        self.dismissIconResource = themeOverride?.dismissIconResource
        ?? defaultValues.dismissIconResource

        self.additionalPadding = themeOverride?.additionalPadding
            .map { EdgeInsets(themeOverride: $0, defaults: defaultValues.additionalPadding) }
        ?? defaultValues.additionalPadding

        self.maxWidth = themeOverride?.maxWidth
        ?? defaultValues.maxWidth

        self.maxHeight = themeOverride?.maxHeight
        ?? defaultValues.maxHeight
    }
}

struct HTMLThemeOverride: Decodable, PlistLoadable {
    var hideDismissIcon: Bool?
    var additionalPadding: EdgeInsetsThemeOverride?
    var dismissIconResource: String?
    var maxWidth: Int?
    var maxHeight: Int?

    init?() {
        self.init(plistName: HTMLTheme.defaultPlistName)
    }
}
