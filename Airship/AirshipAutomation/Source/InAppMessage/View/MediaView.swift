/* Copyright Airship and Contributors */


import SwiftUI

#if canImport(WebKit)
import WebKit
#endif

#if canImport(AirshipCore)
import AirshipCore
#endif

struct MediaView: View {
    @EnvironmentObject
    var environment: InAppMessageEnvironment

    var mediaInfo: InAppMessageMediaInfo
    var mediaTheme: InAppMessageTheme.Media

    var body: some View {
        switch mediaInfo.type {
        case .image:
            mediaImageView
        default:
#if canImport(WebKit)
            webView
#else
            EmptyView()
#endif
        }
    }

    @ViewBuilder
    private var mediaImageView: some View {
        AirshipAsyncImage(
            url: mediaInfo.url,
            imageLoader: environment.imageLoader,
            image: { image, imageSize in
                 image
                    .resizable()
                    .scaledToFit()
            },
            placeholder: {
                ProgressView()
            }
        )
        .padding(mediaTheme.padding)

    }

#if canImport(WebKit)
    private var webView: some View {
        InAppMessageMediaWebView(mediaInfo: mediaInfo)
            .aspectRatio(16.0/9.0, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .padding(mediaTheme.padding)
    }
#endif

}

#if canImport(WebKit)
struct InAppMessageMediaWebView: AirshipNativeViewRepresentable {
#if os(macOS)
    typealias NSViewType = WKWebView
    func makeNSView(context: Context) -> WKWebView {
        return makeWebView(context: context)
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        updateView(nsView, context: context)
    }
#else
    typealias UIViewType = WKWebView

    func makeUIView(context: Context) -> WKWebView {
        return makeWebView(context: context)
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        updateView(uiView, context: context)
    }
#endif

    let mediaInfo: InAppMessageMediaInfo

    private var baseURL: URL? {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.airship.sdk"
        return URL(string: "https://\(bundleIdentifier)")
    }

    func makeWebView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()


#if os(macOS)
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setAccessibilityElement(true)
        webView.layer?.backgroundColor = .clear
        webView.setValue(false, forKey: "drawsBackground") // For transparency
#else
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isAccessibilityElement = true
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
#endif

        webView.navigationDelegate = context.coordinator


        if #available(iOS 16.4, *) {
            webView.isInspectable = Airship.isFlying && Airship.config.airshipConfig.isWebViewInspectionEnabled
        }

        return webView
    }

    func updateView(_ uiView: WKWebView, context: Context) {
        switch mediaInfo.type {
        case .video:
            let htmlString = "<body style=\"margin:0\"><video playsinline controls height=\"100%\" width=\"100%\" src=\"\(mediaInfo.url)\"></video></body>"
            uiView.loadHTMLString(htmlString, baseURL: baseURL)
        case .youtube:
            guard var urlComponents = URLComponents(string: mediaInfo.url) else { return }
            urlComponents.query = "playsinline=1"
            if let url = urlComponents.url {
                uiView.load(URLRequest(url: url))
            }
        case .vimeo:
            guard var urlComponents = URLComponents(string: mediaInfo.url) else { return }
            urlComponents.query = "playsinline=1"
            if let url = urlComponents.url {
                uiView.load(URLRequest(url: url))
            }
        case .image:
            break // Do nothing for images
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let challengeResolver: ChallengeResolver

        init(resolver: ChallengeResolver = .shared) {
            self.challengeResolver = resolver
        }

        func webView(_ webView: WKWebView, respondTo challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
            return await challengeResolver.resolve(challenge)
        }
    }
}
#endif

struct MediaInfo {
    let url: String
    let type: InAppMediaType
}

enum InAppMediaType {
    case video, youtube, image, vimeo
}

