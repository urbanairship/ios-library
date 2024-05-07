/* Copyright Airship and Contributors */

import SwiftUI
import WebKit

#if canImport(AirshipCore)
import AirshipCore
#endif

struct MediaView: View {
    var mediaInfo: InAppMessageMediaInfo
    var mediaTheme: MediaTheme
    var imageLoader: AirshipImageLoader? /// Ideally this would be an associated value on the media info enum

    var body: some View {
        switch mediaInfo.type {
        case .image:
            mediaImageView
        default:
            webView
        }
    }

    @ViewBuilder
    private var mediaImageView: some View {
        if let imageLoader = imageLoader {
            AirshipAsyncImage(
                url: mediaInfo.url,
                imageLoader: imageLoader,
                image: { image, _ in
                    image
                        .resizable()
                        .scaledToFit()
                },
                placeholder: {
                    ProgressView()
                }
            )
            .padding(mediaTheme.additionalPadding)
        }
    }

    private var webView: some View {
        InAppMessageMediaWebView(mediaInfo: mediaInfo)
            .padding(mediaTheme.additionalPadding)
    }
}

struct InAppMessageMediaWebView: UIViewRepresentable {
    let mediaInfo: InAppMessageMediaInfo

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false

        if #available(iOS 16.4, *) {
            webView.isInspectable = Airship.isFlying && Airship.config.isWebViewInspectionEnabled
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        switch mediaInfo.type {
        case .video:
            let htmlString = "<body style=\"margin:0\"><video playsinline controls height=\"100%\" width=\"100%\" src=\"\(mediaInfo.url)\"></video></body>"
            uiView.loadHTMLString(htmlString, baseURL: URL(string: mediaInfo.url))
        case .youtube:
            guard var urlComponents = URLComponents(string: mediaInfo.url) else { return }
            urlComponents.query = "playsinline=1"
            if let url = urlComponents.url {
                uiView.load(URLRequest(url: url))
            }
        case .image:
            break // Do nothing for images
        }
    }
}

struct MediaInfo {
    let url: String
    let type: InAppMediaType
}

enum InAppMediaType {
    case video, youtube, image
}
