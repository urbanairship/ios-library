/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Progress view
@available(iOS 13.0.0, tvOS 13.0.0, *)
struct AirshipProgressView : View {
    
    @State var isVisible = false
    
    var body: some View {
        if #available(iOS 14.0.0, tvOS 14.0.0,  *) {
            ProgressView()
        } else {
            #if !os(tvOS) && !os(watchOS)
            FallbackLoader(isAnimating: true)
            #else
            Image(systemName: "arrow.2.circlepath")
                .frame(width: 30, height: 30, alignment: .center)
                .rotationEffect(Angle.degrees(self.isVisible ? 360.0 : 0.0))
                .animation(Animation.linear(duration: 2.0).repeatForever(autoreverses: false))
                .onAppear { self.isVisible = true }
                .onDisappear { self.isVisible = false }
            #endif
        }
    }
}

#if !os(tvOS) && !os(watchOS)
/// Loader
@available(iOS 13.0.0, *)
struct FallbackLoader: UIViewRepresentable {
    
    typealias UIView = UIActivityIndicatorView
    var isAnimating: Bool
 
    fileprivate var configuration = { (indicator: UIView) in }

    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIView { UIView() }
 
    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<Self>) {
        isAnimating ? uiView.startAnimating() : uiView.stopAnimating()
        configuration(uiView)
    }
}

#endif
