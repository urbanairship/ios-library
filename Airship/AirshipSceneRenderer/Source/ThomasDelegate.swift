/* Copyright Airship and Contributors */

import Foundation
public import SwiftUI
@_spi(AirshipInternal) public import AirshipBasement

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public protocol ThomasDelegate: Sendable {

    @MainActor
    func onVisibilityChanged(isVisible: Bool, isForegrounded: Bool)

    @MainActor
    func onReportingEvent(_ event: ThomasReportingEvent)

    @MainActor
    func onDismissed(cancel: Bool)

    @MainActor
    func onStateChanged(_ state: AirshipJSON)

    /// Loads the image at the given URL (from cache if available).
    @MainActor
    func loadImage(url: String) async throws -> AirshipImageData

    /// Prefetches the given image assets so subsequent `loadImage` calls resolve from cache.
    /// Returns an opaque token used to release the prefetched assets, or `nil` if there was
    /// nothing to prefetch (no assets or no image cache).
    @MainActor
    func prefetchImages(_ urls: [String]) async throws -> String?

    /// Releases assets previously prefetched under the given token.
    @MainActor
    func releasePrefetchedImages(token: String)

    /// Runs the given actions. The delegate owns whatever runner is used.
    @MainActor
    func runActions(_ actions: AirshipJSON, layoutContext: ThomasLayoutContext)

    /// Registers channels (email/SMS) produced by a form submission.
    @MainActor
    func registerChannels(_ channels: [ThomasChannelRegistration])

    /// Applies channel/contact attributes produced by a form submission.
    @MainActor
    func applyAttributes(_ attributes: [ThomasAttribute])

    /// Resolves a localized string for the given key.
    @MainActor
    func localizedString(key: String) -> String?

#if !os(tvOS) && !os(watchOS)
    /// Builds a view that loads the given URL. The web view, its native bridge, and action running
    /// are entirely owned by the returned view; it reports load state via `isLoading` so the
    /// renderer can render its own loading treatment.
    @MainActor
    func makeWebView(
        url: String,
        layoutContext: ThomasLayoutContext,
        isLoading: Binding<Bool>,
        onClose: @escaping @MainActor () -> Void
    ) -> any View
#endif
}

public extension ThomasDelegate {
    @MainActor
    func onStateChanged(_ state: AirshipJSON) {
        // no-op
    }

}

@MainActor
public final class ThomasDismissHandle {
    private var onDismissBlocks: [(Bool) -> Void] = []

    public init() {}

    /// Adds a block to be called when ``dismiss(cancel:)`` is invoked. All blocks are run; order is the order they were added.
    func addOnDismiss(_ block: @escaping (Bool) -> Void) {
        onDismissBlocks.append(block)
    }

    public func dismiss(cancel: Bool = false) {
        for block in onDismissBlocks {
            block(cancel)
        }
        onDismissBlocks.removeAll()
    }
}
