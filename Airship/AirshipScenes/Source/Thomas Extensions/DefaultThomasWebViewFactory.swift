/* Copyright Airship and Contributors */

#if !os(tvOS) && !os(watchOS)

@_spi(AirshipInternal) import AirshipSceneRenderer
@_spi(AirshipInternal) import AirshipCore
import SwiftUI

/// The web view factory the SDK wires up by default — builds a `NativeBridge`-backed `WKWebView`.
/// Carries the per-message action runner and native-bridge extension.
@MainActor
struct DefaultThomasWebViewFactory: ThomasWebViewFactory {
    private let actionRunner: any ThomasActionRunner
    private let nativeBridgeExtension: (any NativeBridgeExtensionDelegate)?

    init(
        actionRunner: any ThomasActionRunner,
        nativeBridgeExtension: (any NativeBridgeExtensionDelegate)? = nil
    ) {
        self.actionRunner = actionRunner
        self.nativeBridgeExtension = nativeBridgeExtension
    }

    func makeWebView(
        url: String,
        layoutContext: @escaping @MainActor () -> ThomasLayoutContext,
        isLoading: Binding<Bool>,
        onClose: @escaping @MainActor () -> Void
    ) -> any View {
        AirshipThomasWebView(
            url: url,
            layoutContext: layoutContext,
            actionRunner: actionRunner,
            nativeBridgeExtension: nativeBridgeExtension,
            isLoading: isLoading,
            onClose: onClose
        )
    }
}

#endif
