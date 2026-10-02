/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
public import AirshipBasement

/// Host-provided capabilities the renderer consumes at construction time (e.g. services that
/// can't be reached through the SwiftUI environment because they're needed in `init`). Carried
/// by `ViewFactory` so it reaches any view the factory builds.
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
@MainActor
public protocol ThomasExtensions: Sendable {
    /// Resolves async-view requests. Required (no default) so every conformer must wire one up;
    /// the "no extensions at all" case is expressed by a nil `ThomasExtensions`, not a nil resolver.
    var asyncViewResolver: any AsyncViewResolver { get }

    /// Resolves WKWebView authentication challenges (server-trust pinning, etc.).
    var webViewChallengeResolver: any AirshipWebViewChallengeResolver { get }

    /// Validates text-input fields (email/SMS). `nil` when validation is unavailable (e.g. the SDK
    /// isn't flying), in which case those fields resolve as invalid.
    var inputValidator: (any AirshipInputValidation.Validator)? { get }

    /// Runs on-device AI inference for text inputs. `nil` when no AI manager is available,
    /// in which case `ai_inference` configs are ignored.
    var aiInferenceExecutor: (any SceneAIExecutor)? { get }

    /// Resolves localized strings (e.g. accessibility labels) from the host's resource bundle.
    var localizer: any ThomasLocalizer { get }

    /// Loads and prefetches images. Owns the lifecycle of anything it prefetches; the environment
    /// asks it to release everything on dismiss.
    var imageLoader: any ThomasImageLoader { get }

    /// Runs layout actions (button taps, gestures, automated page actions).
    var actionRunner: any ThomasActionRunner { get }

    /// Applies form-submission results (channel registrations, attribute edits) to the audience.
    var audienceEditor: any ThomasAudienceEditor { get }

    /// Whether presentation transitions (modal/banner show and dismiss) animate. Defaulted to
    /// `true`; a host sets `false` to make a screenshot flow deterministic without waiting out
    /// a real fade.
    var animationsEnabled: Bool { get }

    /// Seeds every `randomize_children` order, so the same seed gives the same orders on every
    /// platform. Defaulted to `nil`, a seed drawn per scene; set only for UI tests and screenshots.
    var randomSeed: String? { get }

#if !os(tvOS) && !os(watchOS)
    /// Builds web views for `webView` layout nodes (renderer owns no WebKit/native bridge).
    var webViewFactory: any ThomasWebViewFactory { get }
#endif
}

@_spi(AirshipInternal)
extension ThomasExtensions {
    public var animationsEnabled: Bool { true }
    public var randomSeed: String? { nil }
}
