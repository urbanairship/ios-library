/* Copyright Airship and Contributors */

#if !os(tvOS) && !os(watchOS)

import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct MediaWebView: UIViewRepresentable {
    
    typealias UIViewType = WKWebView
    
    let url: String
    let type: MediaType
    let accessibilityLabel: String?
    
    @available(iOS 13.0.0, tvOS 13.0, *)
    func makeUIView(context: Context) -> WKWebView {
        return createWebView()
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
    }
    
    func createWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        
        let webView = WKWebView(frame:.zero, configuration: config)
        webView.isAccessibilityElement = true
        webView.accessibilityLabel = accessibilityLabel
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = UIColor.black
        webView.scrollView.backgroundColor = UIColor.black
        if (type == .video) {
            let html = String(format: "<body style=\"margin:0\"><video playsinline controls height=\"100%%\" width=\"100%%\" src=\"%@\"></video></body>",url)
            guard let mediaUrl = URL(string:url) else { return webView}
            webView.loadHTMLString(html, baseURL:mediaUrl)
        } else if (type == .youtube) {
            guard let url = URL(string:String(format: "%@%@", url, "?playsinline=1")) else { return webView}
            let request = URLRequest(url: url)
            webView.load(request)
        }
        return webView
    }
}

#endif
