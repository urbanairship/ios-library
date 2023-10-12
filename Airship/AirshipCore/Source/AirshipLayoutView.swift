/* Copyright Airship and Contributors */

import SwiftUI

/**
 * Internal only
 * :nodoc:
 */
public struct AirshipLayoutView : View  {
    private let view: () -> EmbeddedView
    private let onDismiss: () -> Void

    internal init(
        view: @escaping () -> EmbeddedView,
        onDismiss: @escaping () -> Void
    ) {
        self.view = view
        self.onDismiss = onDismiss
    }

    public func dismiss() {
        self.onDismiss()
    }

    @ViewBuilder
    public var body: some View {
        view()
    }
}


