/* Copyright Airship and Contributors */

#if !os(tvOS) && !os(watchOS)


import SwiftUI
import WebKit


struct MediaWebView: UIViewRepresentable {

    typealias UIViewType = WKWebView

    let info: ThomasViewInfo.Media
    let onMediaReady: @MainActor () -> Void
    @Environment(\.isVisible) var isVisible
    @State private var isLoaded: Bool = false
    @State private var isMediaReady: Bool = false
    @EnvironmentObject var pagerState: PagerState
    @Environment(\.layoutDirection) var layoutDirection


    private var video: ThomasViewInfo.Media.Video? {
        self.info.properties.video
    }

    private var url: String {
        self.info.properties.url
    }

    private var styleForVideo: String {
        switch(self.info.properties.mediaFit) {
        case .centerInside:
            return "object-fit: contain"
        case .center:
            return "object-fit: none"
        case .fitCrop:
            guard let position = self.info.properties.cropPosition else {
                return "object-fit: cover"
            }

            let horizontal = switch(position.horizontal) {
            case .center:
                "center"
            case .start:
                if layoutDirection == .leftToRight {
                    "left"
                } else {
                    "right"
                }
            case .end:
                if layoutDirection == .leftToRight {
                    "right"
                } else {
                    "left"
                }
            }

            let vertical = switch(position.vertical) {
            case .center:
                "center"
            case .top:
                "top"
            case .bottom:
                "bottom"
            }

            return "width: 100vw; height: 100vh; object-fit: cover; object-position: \(horizontal) \(vertical)"
        case .centerCrop:
            return "object-fit: cover"
        }
    }


    @MainActor
    func makeUIView(context: Context) -> WKWebView {
        return createWebView(context: context)
    }

    @MainActor
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if (pagerState.inProgress) {
            switch (isVisible, isLoaded) {
            case (true, true):
                handleAutoplayingVideos(uiView: uiView)
            case (false, true):
                resetMedias(uiView: uiView)
                pauseMedias(uiView: uiView)
            default:
                pauseMedias(uiView: uiView)
            }
        } else {
            pauseMedias(uiView: uiView)
        }
    }

    @MainActor
    func createWebView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
          contentController.add(makeCoordinator(), name: "callback")
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isAccessibilityElement = true
        webView.accessibilityLabel = self.info.accessible.contentDescription
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        webView.scrollView.backgroundColor = UIColor.clear
        webView.navigationDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        if #available(iOS 16.4, *) {
            webView.isInspectable = Airship.isFlying && Airship.config.airshipConfig.isWebViewInspectionEnabled
        }

        let video = self.info.properties.video
        if self.info.properties.mediaType == .video {
            let html = String(
                format: """
                    <body style="margin:0">
                        <video id="video" playsinline %@ %@ %@ %@ height="100%%" width="100%%" src="%@" style="%@"></video>

                        <script>
                            let videoElement = document.getElementById("video");
                                        
                            videoElement.addEventListener("canplay", (event) => {
                                webkit.messageHandlers.callback.postMessage('mediaReady');
                            });
                        </script>
                    </body>
                    """,
                video?.showControls ?? true ? "controls" : "",
                video?.autoplay ?? false ? "autoplay" : "",
                video?.muted ?? false ? "muted" : "",
                video?.loop ?? false ? "loop" : "",
                url,
                styleForVideo
            )
            guard let mediaUrl = URL(string: url) else { return webView }
            webView.loadHTMLString(html, baseURL: mediaUrl)
        } else if self.info.properties.mediaType == .youtube {
            if let videoID = retrieveYoutubeVideoID(url: url) {
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
                              },
                              events: {
                                'onReady': onPlayerReady
                              }
                            });
                          }
                    
                          function onPlayerReady(event) {
                            webkit.messageHandlers.callback.postMessage('mediaReady');
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
        } else if self.info.properties.mediaType == .vimeo {
            let html = String(
                format: """
                <head><meta name="viewport" content="initial-scale=1,maximum-scale=1"></head>
                <body style="margin:0">
                  
                    <iframe id="vimeoIframe"
                      src="%@&playsinline=1"
                      width="100%%" height="100%%" frameborder="0"
                      webkitallowfullscreen mozallowfullscreen allowfullscreen></iframe>
                  
                  <script src="https://player.vimeo.com/api/player.js"></script>
                  <script>
                    const vimeoIframe = document.querySelector('#vimeoIframe');
                    const vimeoPlayer = new Vimeo.Player(vimeoIframe);
                                        
                    vimeoPlayer.ready().then(function() {
                      webkit.messageHandlers.callback.postMessage('mediaReady');
                    });
                  </script>
                </body>
                """,
                url
            )
            guard let mediaUrl = URL(string: url) else { return webView }
            webView.loadHTMLString(html, baseURL: mediaUrl)
        }
        return webView
    }
    
    func retrieveYoutubeVideoID(url: String) -> String? {
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

    @MainActor
    func handleAutoplayingVideos(uiView: WKWebView) {
        if isVisible {
            if video?.autoplay ?? false {
                playMedias(uiView: uiView)
            }
        } else {
            pauseMedias(uiView: uiView)
        }
    }

    @MainActor
    func pauseMedias(uiView: WKWebView) {
        if self.info.properties.mediaType == .video {
            uiView.evaluateJavaScript("videoElement.pause();")
        } else if self.info.properties.mediaType == .youtube {
            uiView.evaluateJavaScript("player.pauseVideo();")
        } else if self.info.properties.mediaType == .vimeo {
            uiView.evaluateJavaScript("vimeoPlayer.pause();")
        }
    }

    @MainActor
    func resetMedias(uiView: WKWebView) {
        if video?.autoplay ?? false {
            if self.info.properties.mediaType == .video {
                uiView.evaluateJavaScript("videoElement.currentTime = 0;")
            } else if self.info.properties.mediaType == .youtube {
                uiView.evaluateJavaScript("player.seekTo(0);")
            } else if self.info.properties.mediaType == .vimeo {
                uiView.evaluateJavaScript("vimeoPlayer.setCurrentTime(0);")
            }
        }
    }

    @MainActor
    func playMedias(uiView: WKWebView) {
        if self.info.properties.mediaType == .video {
            uiView.evaluateJavaScript("videoElement.play();")
        } else if self.info.properties.mediaType == .youtube {
            uiView.evaluateJavaScript("player.playVideo();")
            uiView.evaluateJavaScript("player.addEventListener(\"onReady\", \"onPlayerReady\");")
        } else if self.info.properties.mediaType == .vimeo {
            uiView.evaluateJavaScript("vimeoPlayer.play();")
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self, isLoaded: $isLoaded, onMediaReady: onMediaReady)
    }
        
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: MediaWebView
        var isLoaded: Binding<Bool>
        var onMediaReady: @MainActor () -> Void
        let challengeResolver: ChallengeResolver

        init(
            _ parent: MediaWebView,
            isLoaded: Binding<Bool>,
            resolver: ChallengeResolver = .shared,
            onMediaReady: @escaping @MainActor () -> Void) {
                
                self.parent = parent
                self.isLoaded = isLoaded
                self.onMediaReady = onMediaReady
                self.challengeResolver = resolver
            }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded.wrappedValue = true
        }
        
        func webView(_ webView: WKWebView, respondTo challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
            return await challengeResolver.resolve(challenge)
        }
        
        @MainActor
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let response = message.body as? String else {
                return
            }
            
            if (response == "mediaReady") {
                onMediaReady()
            }
        }
    }
}

#endif
