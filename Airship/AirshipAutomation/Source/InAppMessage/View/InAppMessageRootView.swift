/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif


struct InAppMessageRootView<Content: View>: View {
    @State private var currentOrientation: Orientation = InAppMessageRootView.resolveOrientation()
    @State private var displayedCalled: Bool = false

    @ObservedObject var inAppMessageEnvironment: InAppMessageEnvironment

    let content: (Orientation) -> Content

    init(
        inAppMessageEnvironment: InAppMessageEnvironment,
        @ViewBuilder content: @escaping (Orientation) -> Content
    ) {
        self.inAppMessageEnvironment = inAppMessageEnvironment
        self.content = content
    }

    @ViewBuilder
    var body: some View {
        content(currentOrientation)
            .environmentObject(inAppMessageEnvironment)
            .environment(\.orientation, currentOrientation)
            .onAppear {
                self.currentOrientation = InAppMessageRootView.resolveOrientation()
            }
        #if os(iOS)
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIDevice.orientationDidChangeNotification
                )
            ) { _ in
                self.currentOrientation = InAppMessageRootView.resolveOrientation()
            }
        #endif
    }

    static func resolveOrientation() -> Orientation {
        if let scene = try? SceneManager.shared.lastActiveScene {
            if scene.interfaceOrientation.isLandscape {
                return .landscape
            } else if scene.interfaceOrientation.isPortrait {
                return .portrait
            }
        }
        return .portrait
    }
}
