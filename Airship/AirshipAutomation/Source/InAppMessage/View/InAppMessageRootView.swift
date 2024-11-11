/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

struct InAppMessageRootView<Content: View>: View {
    @State private var displayedCalled: Bool = false

    @ObservedObject var inAppMessageEnvironment: InAppMessageEnvironment

    let content: () -> Content

    init(
        inAppMessageEnvironment: InAppMessageEnvironment,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.inAppMessageEnvironment = inAppMessageEnvironment
        self.content = content
    }

    @ViewBuilder
    var body: some View {
        content()
            .environmentObject(inAppMessageEnvironment)
    }
}

extension View {
    @ViewBuilder
    func iaaApplyIf<Content: View>(
        _ predicate: @autoclosure () -> Bool,
        @ViewBuilder transform: (Self) -> Content
    ) -> some View {
        if predicate() {
            transform(self)
        } else {
            self
        }
    }
}
