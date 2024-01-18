/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

struct BannerTheme: Equatable {
    var additionalPadding: EdgeInsets
    var maxWidth: Int
    var headerTheme: TextTheme
    var bodyTheme: TextTheme
    var mediaTheme: MediaTheme
    var buttonTheme: ButtonTheme

    /// Used for testing
    init(plistName: String,
         bundle: Bundle? = Bundle.main) {
        let overrides = BannerThemeOverride(plistName: plistName, bundle: bundle)
        self.init(themeOverride: overrides)
    }

    init(additionalPadding: EdgeInsets,
         maxWidth: Int,
         headerTheme: TextTheme,
         bodyTheme: TextTheme,
         mediaTheme: MediaTheme,
         buttonTheme: ButtonTheme) {
        self.additionalPadding = additionalPadding
        self.maxWidth = maxWidth
        self.headerTheme = headerTheme
        self.bodyTheme = bodyTheme
        self.mediaTheme = mediaTheme
        self.buttonTheme = buttonTheme
    }

    init(themeOverride:BannerThemeOverride? = BannerThemeOverride(plistName: defaultPlistName, bundle: Bundle.main),
         defaultValues:BannerTheme = Self.defaultValues) {
        self.additionalPadding = themeOverride?.additionalPadding
            .map { EdgeInsets(themeOverride: $0, defaults: defaultValues.additionalPadding) }
        ?? defaultValues.additionalPadding

        self.maxWidth = themeOverride?.maxWidth
        ?? BannerTheme.defaultValues.maxWidth

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
    }
}

struct BannerThemeOverride: Decodable, PlistLoadable {
    var additionalPadding: EdgeInsetsThemeOverride?
    var maxWidth: Int?
    var headerTheme: TextThemeOverride?
    var bodyTheme: TextThemeOverride?
    var mediaTheme: MediaThemeOverride?
    var buttonTheme: ButtonThemeOverride?

    init(additionalPadding: EdgeInsetsThemeOverride? = nil,
         maxWidth: Int? = nil,
         headerTheme: TextThemeOverride? = nil,
         bodyTheme: TextThemeOverride? = nil,
         mediaTheme: MediaThemeOverride? = nil,
         buttonTheme: ButtonThemeOverride? = nil) {
        self.additionalPadding = additionalPadding
        self.maxWidth = maxWidth
        self.headerTheme = headerTheme
        self.bodyTheme = bodyTheme
        self.mediaTheme = mediaTheme
        self.buttonTheme = buttonTheme
    }

    init?() {
        self.init(plistName: BannerTheme.defaultPlistName)
    }

    enum CodingKeys: String, CodingKey {
        case additionalPadding = "additionalPadding"
        case maxWidth = "maxWidth"
        case headerTheme = "headerStyle"
        case bodyTheme = "bodyStyle"
        case mediaTheme = "mediaStyle"
        case buttonTheme = "buttonStyle"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        additionalPadding = try container.decodeIfPresent(EdgeInsetsThemeOverride.self, forKey: .additionalPadding)
        headerTheme = try container.decodeIfPresent(TextThemeOverride.self, forKey: .headerTheme)
        bodyTheme = try container.decodeIfPresent(TextThemeOverride.self, forKey: .bodyTheme)
        mediaTheme = try container.decodeIfPresent(MediaThemeOverride.self, forKey: .mediaTheme)
        buttonTheme = try container.decodeIfPresent(ButtonThemeOverride.self, forKey: .buttonTheme)
        maxWidth = try container.decodeIfPresent(Int.self, forKey: .maxWidth)
    }
}
