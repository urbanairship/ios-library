/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct ModalTheme: Equatable {
    var additionalPadding: EdgeInsets
    var headerTheme: TextTheme
    var bodyTheme: TextTheme
    var mediaTheme: MediaTheme
    var buttonTheme: ButtonTheme
    var dismissIconResource: String
    var maxWidth: Int
    var maxHeight: Int

    /// Used for testing
    init(plistName: String,
         bundle: Bundle? = Bundle.main) {
        let overrides = ModalThemeOverride(plistName: plistName, bundle: bundle)
        self.init(themeOverride: overrides)
    }

    init(additionalPadding: EdgeInsets,
         headerTheme: TextTheme,
         bodyTheme: TextTheme,
         mediaTheme: MediaTheme,
         buttonTheme: ButtonTheme,
         dismissIconResource: String,
         maxWidth: Int,
         maxHeight: Int) {
        self.additionalPadding = additionalPadding
        self.headerTheme = headerTheme
        self.bodyTheme = bodyTheme
        self.mediaTheme = mediaTheme
        self.buttonTheme = buttonTheme
        self.dismissIconResource = dismissIconResource
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
    }

    init(themeOverride:ModalThemeOverride? = ModalThemeOverride(plistName: Self.defaultPlistName, bundle: Bundle.main),
         defaultValues:ModalTheme = Self.defaultValues) {
        self.additionalPadding = themeOverride?.additionalPadding.map { EdgeInsets(themeOverride: $0, defaults: defaultValues.additionalPadding) } ?? Self.defaultValues.additionalPadding

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
            .map { ButtonTheme(themeOverride: $0, defaults: defaultValues.buttonTheme) }
        ?? defaultValues.buttonTheme

        self.dismissIconResource = themeOverride?.dismissIconResource
        ?? defaultValues.dismissIconResource

        self.maxWidth = themeOverride?.maxWidth
        ?? defaultValues.maxWidth

        self.maxHeight = themeOverride?.maxHeight
        ?? defaultValues.maxHeight
    }
}

struct ModalThemeOverride: Decodable, PlistLoadable {
    var additionalPadding: EdgeInsetsThemeOverride?
    var headerTheme: TextThemeOverride?
    var bodyTheme: TextThemeOverride?
    var mediaTheme: MediaThemeOverride?
    var buttonTheme: ButtonThemeOverride?
    var dismissIconResource: String?
    var maxWidth: Int?
    var maxHeight: Int?

    init?() {
        self.init(plistName: ModalTheme.defaultPlistName)
    }

    enum CodingKeys: String, CodingKey {
        case additionalPadding = "additionalPadding"
        case headerTheme = "headerStyle"
        case bodyTheme = "bodyStyle"
        case mediaTheme = "mediaStyle"
        case buttonTheme = "buttonStyle"
        case dismissIconResource = "dismissIconResource"
        case maxWidth = "maxWidth"
        case maxHeight = "maxHeight"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        headerTheme = try container.decodeIfPresent(TextThemeOverride.self, forKey: .headerTheme)
        bodyTheme = try container.decodeIfPresent(TextThemeOverride.self, forKey: .bodyTheme)
        mediaTheme = try container.decodeIfPresent(MediaThemeOverride.self, forKey: .mediaTheme)
        buttonTheme = try container.decodeIfPresent(ButtonThemeOverride.self, forKey: .buttonTheme)
        dismissIconResource = try container.decodeIfPresent(String.self, forKey: .dismissIconResource)
        maxWidth = try container.decodeIfPresent(Int.self, forKey: .maxWidth)
        maxHeight = try container.decodeIfPresent(Int.self, forKey: .maxHeight)
        additionalPadding = try container.decodeIfPresent(EdgeInsetsThemeOverride.self, forKey: .additionalPadding)
    }
}
