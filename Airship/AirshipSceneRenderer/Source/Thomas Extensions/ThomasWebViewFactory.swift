/* Copyright Airship and Contributors */

#if !os(tvOS) && !os(watchOS)

import Foundation
public import SwiftUI

/// Builds the web view for `webView` layout nodes. Host-provided so the renderer never needs to
/// know about WebKit or the native bridge. The web view, its bridge, and action running are owned
/// entirely by the returned view.
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
@MainActor
public protocol ThomasWebViewFactory: Sendable {
    /// Builds a view that loads the given URL. `layoutContext` is a provider, not a snapshot —
    /// actions triggered from the web view resolve it when they fire, so they see the current
    /// layout state rather than whatever it was at build time. `isLoading` reports load state so
    /// the renderer can render its own loading treatment.
    func makeWebView(
        url: String,
        layoutContext: @escaping @MainActor () -> ThomasLayoutContext,
        isLoading: Binding<Bool>,
        onClose: @escaping @MainActor () -> Void
    ) -> any View
}

#endif
