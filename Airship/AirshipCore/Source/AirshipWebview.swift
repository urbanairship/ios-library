/* Copyright Airship and Contributors */

#if !os(tvOS)

import Foundation
import SwiftUI
import Combine
import WebKit

/// Airship Webview
@available(iOS 13.0.0, *)
struct AirshipWebView : View {

    let model: WebViewModel

    let constraints: ViewConstraints

    var body: some View {
        WebViewView(request: URLRequest(url: URL(string: model.url)!))
            .constraints(constraints)
    }
}

/// Webview
@available(iOS 13.0.0, *)
struct WebViewView : UIViewRepresentable {
    
    typealias UIViewType = WKWebView
    
    let request: URLRequest
    
    func makeUIView(context: Context) -> WKWebView  {
        return WKWebView()
    }
        
    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.load(request)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}

@available(iOS 13.0.0, *)
class Coordinator : NSObject, WKNavigationDelegate {
       
    var webView: WebViewView
        
    init(_ uiWebView: WebViewView) {
        self.webView = uiWebView
    }
}


#endif
