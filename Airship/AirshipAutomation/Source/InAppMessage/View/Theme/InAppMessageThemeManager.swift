/* Copyright Airship and Contributors */

import Foundation
import SwiftUI


#if canImport(AirshipCore)
import AirshipCore
#endif

/// Theme manager for in-app messages.
@MainActor
public final class InAppAutomationThemeManager {

    /// Sets the html theme extender block
    public var htmlThemeExtender: (@MainActor (InAppMessage, inout InAppMessageTheme.HTML) -> Void)?

    /// Sets the modal theme extender block
    public var modalThemeExtender: (@MainActor (InAppMessage, inout InAppMessageTheme.Modal) -> Void)?

    /// Sets the fullscreen theme extender block
    public var fullscreenThemeExtender: (@MainActor (InAppMessage, inout InAppMessageTheme.Fullscreen) -> Void)?

    /// Sets the banner theme extender block
    public var bannerThemeExtender: (@MainActor (InAppMessage, inout InAppMessageTheme.Banner) -> Void)?


    func makeHTMLTheme(message: InAppMessage) -> InAppMessageTheme.HTML {
        var theme = InAppMessageTheme.HTML.defaultTheme
        htmlThemeExtender?(message, &theme)
        return theme
    }

    func makeModalTheme(message: InAppMessage) -> InAppMessageTheme.Modal {
        var theme = InAppMessageTheme.Modal.defaultTheme
        modalThemeExtender?(message, &theme)
        return theme
    }

    func makeFullscreenTheme(message: InAppMessage) -> InAppMessageTheme.Fullscreen {
        var theme = InAppMessageTheme.Fullscreen.defaultTheme
        fullscreenThemeExtender?(message, &theme)
        return theme
    }

    func makeBannerTheme(message: InAppMessage) -> InAppMessageTheme.Banner {
        var theme = InAppMessageTheme.Banner.defaultTheme
        bannerThemeExtender?(message, &theme)
        return theme
    }
}
