/* Copyright Airship and Contributors */

#if !os(tvOS) && !os(watchOS)

import Foundation
import SwiftUI


struct MediaWebView: UIViewRepresentable {

    typealias UIViewType = WKWebView

    let url: String
    let type: MediaType
    let accessibilityLabel: String?
    let video: Video?
    
    func makeUIView(context: Context) -> WKWebView {
        return createWebView()
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
    }

    func createWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isAccessibilityElement = true
        webView.accessibilityLabel = accessibilityLabel
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = UIColor.black
        webView.scrollView.backgroundColor = UIColor.black
        if type == .video {
            let html = String(
                format: "<body style=\"margin:0\"><video playsinline %@ %@ %@ %@ height=\"100%%\" width=\"100%%\" src=\"%@\"></video></body>",
                video?.showControls ?? true ? "controls" : "",
                video?.autoplay ?? false ? "autoplay" : "",
                video?.muted ?? false ? "muted" : "",
                video?.loop ?? false ? "loop" : "",
                url
            )
            guard let mediaUrl = URL(string: url) else { return webView }
            webView.loadHTMLString(html, baseURL: mediaUrl)
        } else if type == .youtube {
            guard
                let url = URL(
                    string: String(format: "%@%@", url, "?playsinline=1")
                )
            else { return webView }
            let request = URLRequest(url: url)
            webView.load(request)
        }
        return webView
    }
}

#endif
