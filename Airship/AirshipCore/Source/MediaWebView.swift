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
    @Environment(\.isVisible) var isVisible
    @State private var isLoaded: Bool = false
    
    func makeUIView(context: Context) -> WKWebView {
        return createWebView(context: context)
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if isLoaded {
            handleAutoplayingVideos(uiView: uiView)
        } else {
            pauseMedias(uiView: uiView)
        }
    }

    func createWebView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isAccessibilityElement = true
        webView.accessibilityLabel = accessibilityLabel
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = UIColor.black
        webView.scrollView.backgroundColor = UIColor.black
        webView.navigationDelegate = context.coordinator
        if type == .video {
            let html = String(
                format: """
                    <body style="margin:0">
                        <video id="video" playsinline %@ %@ %@ %@ height="100%%" width="100%%" src="%@"></video>
                        
                        <script>
                            let videoElement = document.getElementById("video");
                        </script>
                    </body>
                    """,
                video?.showControls ?? true ? "controls" : "",
                video?.autoplay ?? false ? "autoplay" : "",
                video?.muted ?? false ? "muted" : "",
                video?.loop ?? false ? "loop" : "",
                url
            )
            guard let mediaUrl = URL(string: url) else { return webView }
            webView.loadHTMLString(html, baseURL: mediaUrl)
        } else if type == .youtube {
            if let videoID = retrieveVideoID(url: url) {
                let html = String(
                    format: """
                    <body style="margin:0">
                        <!-- 1. The <iframe> (and video player) will replace this <div> tag. -->
                        <div id="player"></div>
                    
                        <script>
                          // 2. This code loads the IFrame Player API code asynchronously.
                          var tag = document.createElement('script');
                    
                          tag.src = "https://www.youtube.com/iframe_api";
                          var firstScriptTag = document.getElementsByTagName('script')[0];
                          firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
                    
                          // 3. This function creates an <iframe> (and YouTube player)
                          //    after the API code downloads.
                          var player;
                          function onYouTubeIframeAPIReady() {
                            player = new YT.Player('player', {
                              height: '100%%',
                              width: '100%%',
                              videoId: '%@',
                              playerVars: {
                                'playsinline': 1,
                                'modestbranding': 1,
                                'controls': %@,
                                'autoplay': %@,
                                'mute': %@,
                                'loop': %@
                              }
                            });
                          }
                        </script>
                    </body>
                    """,
                    videoID,
                    video?.showControls ?? true ? "1" : "0",
                    video?.autoplay ?? false ? "1" : "0",
                    video?.muted ?? false ? "1" : "0",
                    video?.loop ?? false ? "1, \'playlist\': \'\(videoID)\'" : "0"
                )
                guard let mediaUrl = URL(string: url) else { return webView }
                webView.loadHTMLString(html, baseURL: mediaUrl)
            } else {
                guard let videoUrl = URL(string: String(format: "%@%@", url, "?playsinline=1")) else {
                    return webView
                }
                webView.load(URLRequest(url: videoUrl))
            }
        }
        return webView
    }
    
    func retrieveVideoID(url: String) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: "embed/([a-zA-Z0-9_-]+).*")
            let results = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url))
            let result = results.map {
                String(url[Range($0.range, in: url)!])
            }
            guard let result = result else {
                return nil
            }
            let separatedResult = result.components(separatedBy: "/")
            return separatedResult[1]
        } catch _ {
            return nil
        }
    }
    
    func handleAutoplayingVideos(uiView: WKWebView) {
        if isVisible {
            if video?.autoplay ?? false {
                playMedias(uiView: uiView)
            }
        } else {
            pauseMedias(uiView: uiView)
        }
    }
    
    func pauseMedias(uiView: WKWebView) {
        if type == .video {
            uiView.evaluateJavaScript("videoElement.pause();")
        } else if type == .youtube {
            uiView.evaluateJavaScript("player.pauseVideo();")
        }
    }
    
    func playMedias(uiView: WKWebView) {
        if type == .video {
            uiView.evaluateJavaScript("videoElement.play();")
        } else if type == .youtube {
            uiView.evaluateJavaScript("player.playVideo();")
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self, isLoaded: $isLoaded)
    }
        
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: MediaWebView
        var isLoaded: Binding<Bool>

        init(_ parent: MediaWebView, isLoaded: Binding<Bool>) {
            self.parent = parent
            self.isLoaded = isLoaded
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded.wrappedValue = true
        }
    }
}

#endif
