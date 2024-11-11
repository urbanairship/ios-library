/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

struct InAppMessageRootView<Content: View>: View {
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

