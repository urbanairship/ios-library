/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif


struct InAppMessageRootView<Content: View>: View {

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var currentOrientation: Orientation = InAppMessageRootView.resolveOrientation()
    @State private var isVisible: Bool = false
    @State private var displayedCalled: Bool = false

    @ObservedObject var inAppMessageEnvironment: InAppMessageEnvironment

    let content: (Orientation, WindowSize) -> Content

    init(
        inAppMessageEnvironment: InAppMessageEnvironment,
        @ViewBuilder content: @escaping (Orientation, WindowSize) -> Content
    ) {
        self.inAppMessageEnvironment = inAppMessageEnvironment
        self.content = content
    }

    @ViewBuilder
    var body: some View {
        content(currentOrientation, resolveWindowSize())
            .environmentObject(inAppMessageEnvironment)
            .environment(\.orientation, currentOrientation)
            .environment(\.windowSize, resolveWindowSize())
            .environment(\.isVisible, isVisible)
            .onAppear {
                self.currentOrientation = InAppMessageRootView.resolveOrientation()
                self.isVisible = true
            }
            .onDisappear {
                self.isVisible = false
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIDevice.orientationDidChangeNotification
                )
            ) { _ in
                self.currentOrientation = InAppMessageRootView.resolveOrientation()
            }
    }

    /// Uses the vertical and horizontal class size to determine small, medium, large window size:
    /// - large: regular x regular = large
    /// - medium: regular x compact or compact x regular
    /// - small: compact x compact
    func resolveWindowSize() -> WindowSize {
        switch (verticalSizeClass, horizontalSizeClass) {
        case (.regular, .regular):
            return .large
        case (.compact, .compact):
            return .small
        default:
            return .medium
        }
    }

    static func resolveOrientation() -> Orientation {
        if let scene = UIApplication.shared.windows.first?.windowScene {
            if scene.interfaceOrientation.isLandscape {
                return .landscape
            } else if scene.interfaceOrientation.isPortrait {
                return .portrait
            }
        }
        return .portrait
    }
}
