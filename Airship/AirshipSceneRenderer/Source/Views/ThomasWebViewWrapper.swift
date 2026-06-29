/* Copyright Airship and Contributors */

#if !os(tvOS) && !os(watchOS)

import Foundation
import SwiftUI

/// Thin renderer-side wrapper: embeds the host-provided web view, owns the loading overlay, and
/// applies Thomas layout modifiers. The renderer has no knowledge of WebKit or the native bridge.
struct ThomasWebViewWrapper: View {

    let info: ThomasViewInfo.WebView
    let constraints: ViewConstraints
    let webViewFactory: any ThomasWebViewFactory

    @State private var isLoading: Bool = true
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment
    @Environment(\.layoutState) var layoutState

    var body: some View {
        ZStack {
            AnyView(
                self.webViewFactory.makeWebView(
                    url: self.info.properties.url,
                    // Provider, not a snapshot: actions triggered from the web view run with the layout
                    // context as it is *when the action fires*, not as it was when the view was built.
                    layoutContext: { [weak thomasEnvironment, layoutState] in
                        thomasEnvironment?.makeLayoutContext(layoutState: layoutState) ?? ThomasLayoutContext()
                    },
                    isLoading: self.$isLoading,
                    onClose: {
                        self.thomasEnvironment.dismiss(layoutState: self.layoutState)
                    }
                )
            )
            .opacity(self.isLoading ? 0.0 : 1.0)

            if self.isLoading {
                AirshipProgressView()
            }
        }
        .constraints(constraints)
        .thomasCommon(self.info)
    }
}

#endif
