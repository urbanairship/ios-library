/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct RootViewModifier: ViewModifier {
    
#if !os(tvOS)
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif
    
    @State private var currentOrientation: Orientation = RootViewModifier.resolveOrientation()
    
    let context: ThomasContext
    
    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .environmentObject(context)
            .environment(\.orientation, currentOrientation)
            .environment(\.windowSize, resolveWindowSize())
            .onAppear {
                self.currentOrientation = RootViewModifier.resolveOrientation()
            }
            #if !os(tvOS)
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                self.currentOrientation = RootViewModifier.resolveOrientation()
            }
            #endif
    }
    
    
    /// Uses the vertical and horizontal class size to determine small, medium, large window size:
    /// - large: regular x regular = large
    /// - medium: regular x compact or compact x regular
    /// - small: compact x compact
    func resolveWindowSize() -> WindowSize {
#if os(tvOS)
        return .large
#else
        switch(verticalSizeClass, horizontalSizeClass) {
        case (.regular, .regular):
            return .large
        case (.compact, .compact):
            return .small
        default:
            return .medium
        }
#endif
    }
    
    static func resolveOrientation() -> Orientation {
        #if os(tvOS)
        return .landscape
        #else
        if let scene = UIApplication.shared.windows.first?.windowScene {
            if (scene.interfaceOrientation.isLandscape) {
                return .landscape
            } else if (scene.interfaceOrientation.isPortrait) {
                return .portrait
            }
        }
        return .portrait
        #endif
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
extension View {
    @ViewBuilder
    func root(context: ThomasContext) -> some View {
        self.modifier(RootViewModifier(context: context))
    }
}

