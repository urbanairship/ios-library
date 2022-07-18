/* Copyright Airship and Contributors */

#if !os(tvOS) && !os(watchOS)

import Foundation
import SwiftUI
import WebKit

/// Airship Webview
@available(iOS 13.0.0, *)
struct AirshipWebView : View {

    let model: WebViewModel

    let constraints: ViewConstraints
    
    @State var isLoading: Bool = false
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment
    @Environment(\.layoutState) var layoutState

    var body: some View {
        
        ZStack {
            WebViewView(url: self.model.url,
                        nativeBridgeExtension: self.thomasEnvironment.extensions?.nativeBridgeExtension,
                        isLoading: self.$isLoading) {
                thomasEnvironment.dismiss(layoutState: layoutState)
            }
            .opacity(self.isLoading ? 0.0 : 1.0)
            
            if (self.isLoading) {
                AirshipProgressView()
            }
        }
        .constraints(constraints)
        .background(self.model.backgroundColor)
        .border(self.model.border)
        .common(self.model)
    }
}

/// Webview
@available(iOS 13.0.0, *)
struct WebViewView : UIViewRepresentable  {
    typealias UIViewType = WKWebView
    
    let url: String
    let nativeBridgeExtension: NativeBridgeExtensionDelegate?
    @Binding var isLoading: Bool
    
    let onDismiss: () -> Void
    
    func makeUIView(context: Context) -> WKWebView  {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator.nativeBridge
        
        if let url = URL(string: self.url) {
            updateLoading(true)
            webView.load(URLRequest(url: url))
        }

        return webView
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
        
    func updateUIView(_ uiView: WKWebView, context: Context) {
        print(self.isLoading)
    }
    
    func updateLoading(_ isLoading: Bool) {
        DispatchQueue.main.async {
            self.isLoading = isLoading
        }
    }
    
    class Coordinator : NSObject, UANavigationDelegate, JavaScriptCommandDelegate, NativeBridgeDelegate {
        private let parent: WebViewView
        let nativeBridge: NativeBridge

        init(_ parent: WebViewView) {
            self.parent = parent
            self.nativeBridge = NativeBridge()
            super.init()
            self.nativeBridge.nativeBridgeExtensionDelegate = self.parent.nativeBridgeExtension
            self.nativeBridge.forwardNavigationDelegate = self
            self.nativeBridge.javaScriptCommandDelegate = self
            self.nativeBridge.nativeBridgeDelegate = self
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.updateLoading(false)
        }
                
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            parent.updateLoading(true)
            DispatchQueue.main.async {
                webView.reload()
            }
        }
                
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.updateLoading(true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak webView] in
                webView?.reload()
            }
        }
        
        func perform(_ command: JavaScriptCommand, webView: WKWebView) -> Bool {
            return false
        }
        
        func close() {
            DispatchQueue.main.async {
                self.parent.onDismiss()
            }
        }
    }
}

#endif
