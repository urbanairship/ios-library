/* Copyright Airship and Contributors */

#if !os(tvOS) && !os(watchOS)

import Foundation
import SwiftUI
import WebKit


struct MediaWebView: AirshipNativeViewRepresentable {

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

    let info: ThomasViewInfo.Media
    let videoIdentifier: String?
    let onMediaReady: @MainActor () -> Void
    @Environment(\.isVisible) var isVisible
    @State private var isLoaded: Bool = false
    @State private var isMediaReady: Bool = false
    @EnvironmentObject var pagerState: PagerState
    @EnvironmentObject var videoState: VideoState
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

    private var baseURL: URL? {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.airship.sdk"
        return URL(string: "https://\(bundleIdentifier)")
    }


    @MainActor
    func makeWebView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "callback")

        let config = WKWebViewConfiguration()
        config.userContentController = contentController

#if os(macOS)
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setAccessibilityElement(true)
        webView.setAccessibilityLabel(self.info.accessible.contentDescription)
        webView.layer?.backgroundColor = .clear
        webView.setValue(false, forKey: "drawsBackground") // For transparency
#else
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isAccessibilityElement = true
        webView.accessibilityLabel = self.info.accessible.contentDescription
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

        loadMediaContent(webView: webView)

        return webView
    }

    @MainActor
    private func updateView(_ view: WKWebView, context: Context) {
        let justLoaded = !context.coordinator.lastIsLoaded && isLoaded
        let didChange = context.coordinator.lastIsVisible != isVisible
            || context.coordinator.lastIsLoaded != isLoaded
            || context.coordinator.lastInProgress != pagerState.inProgress
        context.coordinator.lastIsVisible = isVisible
        context.coordinator.lastIsLoaded = isLoaded
        context.coordinator.lastInProgress = pagerState.inProgress

        guard didChange else { return }

        if (pagerState.inProgress) {
            switch (isVisible, isLoaded) {
            case (true, true):
                handleAutoplayingVideos(uiView: view, justLoaded: justLoaded)
            case (false, true):
                context.coordinator.isSystemPausing = true
                resetMedias(webView: view)
                pauseMedias(webView: view)
            default:
                context.coordinator.isSystemPausing = true
                pauseMedias(webView: view)
            }
        } else {
            context.coordinator.isSystemPausing = true
            pauseMedias(webView: view)
        }
    }

    @MainActor
    private func loadMediaContent(webView: WKWebView) {
        let video = self.info.properties.video

        switch(info.properties.mediaType) {
        case .image:
            return
        case .video:
            let html = String(
                format: """
                        <body style="margin:0; background-color:transparent;">
                            <video id="video" playsinline %@ %@ %@ %@ height="100%%" width="100%%" src="%@" style="%@"></video>
                        
                            <script>
                                let videoElement = document.getElementById("video");
                                            
                                videoElement.addEventListener("canplay", (event) => {
                                    webkit.messageHandlers.callback.postMessage('mediaReady');
                                    webkit.messageHandlers.callback.postMessage(videoElement.muted ? 'muted' : 'unmuted');
                                });
                                videoElement.addEventListener("play",  () => { webkit.messageHandlers.callback.postMessage('playing'); });
                                videoElement.addEventListener("pause", () => { webkit.messageHandlers.callback.postMessage('paused'); });
                                videoElement.addEventListener("ended", () => { webkit.messageHandlers.callback.postMessage('paused'); });
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
            webView.loadHTMLString(html, baseURL: baseURL)
        case .youtube:
            if let videoID = retrieveYoutubeVideoID(url: url) {
                let html = String(
                    format: """
                        <body style="margin:0; background-color:transparent;">
                            <div id="player"></div>
                        
                            <script>
                              var tag = document.createElement('script');
                        
                              tag.src = "https://www.youtube.com/iframe_api";
                              var firstScriptTag = document.getElementsByTagName('script')[0];
                              firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
                        
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
                                    'onReady': onPlayerReady,
                                    'onStateChange': function(event) {
                                      if (event.data === YT.PlayerState.PLAYING) {
                                        webkit.messageHandlers.callback.postMessage('playing');
                                      } else if (event.data === YT.PlayerState.PAUSED || event.data === YT.PlayerState.ENDED) {
                                        webkit.messageHandlers.callback.postMessage('paused');
                                      }
                                    }
                                  }
                                });
                              }
                        
                              function onPlayerReady(event) {
                                webkit.messageHandlers.callback.postMessage('mediaReady');
                                webkit.messageHandlers.callback.postMessage(player.isMuted() ? 'muted' : 'unmuted');
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
                webView.loadHTMLString(html, baseURL: baseURL)
            } else {
                // FALLBACK: Standard URL loading if ID extraction fails
                // Force playsinline for better mobile behavior
                let suffix = url.contains("?") ? "&playsinline=1" : "?playsinline=1"
                if let videoUrl = URL(string: "\(url)\(suffix)") {
                    webView.load(URLRequest(url: videoUrl))
                }
            }
        case .vimeo:
            let html = String(
                format: """
                    <head><meta name="viewport" content="initial-scale=1,maximum-scale=1"></head>
                    <body style="margin:0; background-color:transparent;">                  
                        <iframe id="vimeoIframe"
                          src="%@&playsinline=1"
                          width="100%%" height="100%%" frameborder="0"
                          webkitallowfullscreen mozallowfullscreen allowfullscreen>
                        </iframe>
                      
                        <script src="https://player.vimeo.com/api/player.js" />
                        <script>
                            const vimeoIframe = document.querySelector('#vimeoIframe');
                            const vimeoPlayer = new Vimeo.Player(vimeoIframe);
                                                
                            vimeoPlayer.ready().then(function() {
                              webkit.messageHandlers.callback.postMessage('mediaReady');
                              vimeoPlayer.on('play',  function() { webkit.messageHandlers.callback.postMessage('playing'); });
                              vimeoPlayer.on('pause', function() { webkit.messageHandlers.callback.postMessage('paused'); });
                              vimeoPlayer.on('ended', function() { webkit.messageHandlers.callback.postMessage('paused'); });
                              return vimeoPlayer.getMuted();
                            }).then(function(muted) {
                              webkit.messageHandlers.callback.postMessage(muted ? 'muted' : 'unmuted');
                            });
                        </script>
                    </body>
                    """,
                url
            )
            webView.loadHTMLString(html, baseURL: baseURL)
        }
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
    func handleAutoplayingVideos(uiView: WKWebView, justLoaded: Bool) {
        if isVisible {
            if video?.autoplay ?? false {
                // On first load always autoplay. On subsequent visibility re-entries
                // (e.g. pager navigation), respect the VideoState — if the user
                // explicitly paused, don't restart the video behind their back.
                if justLoaded || videoState.isPlaying {
                    playMedias(webView: uiView)
                }
            }
        } else {
            pauseMedias(webView: uiView)
        }
    }

    @MainActor
    func pauseMedias(webView: WKWebView) {
        if self.info.properties.mediaType == .video {
            webView.evaluateJavaScript("videoElement.pause();")
        } else if self.info.properties.mediaType == .youtube {
            webView.evaluateJavaScript("player.pauseVideo();")
        } else if self.info.properties.mediaType == .vimeo {
            webView.evaluateJavaScript("vimeoPlayer.pause();")
        }
    }

    @MainActor
    func resetMedias(webView: WKWebView) {
        if video?.autoplay ?? false {
            if self.info.properties.mediaType == .video {
                webView.evaluateJavaScript("videoElement.currentTime = 0;")
            } else if self.info.properties.mediaType == .youtube {
                webView.evaluateJavaScript("player.seekTo(0);")
            } else if self.info.properties.mediaType == .vimeo {
                webView.evaluateJavaScript("vimeoPlayer.setCurrentTime(0);")
            }
        }
    }

    @MainActor
    func playMedias(webView: WKWebView) {
        if self.info.properties.mediaType == .video {
            webView.evaluateJavaScript("videoElement.play();")
        } else if self.info.properties.mediaType == .youtube {
            webView.evaluateJavaScript("player.playVideo();")
        } else if self.info.properties.mediaType == .vimeo {
            webView.evaluateJavaScript("vimeoPlayer.play();")
        }
    }

    @MainActor
    func muteMedias(webView: WKWebView) {
        if self.info.properties.mediaType == .video {
            webView.evaluateJavaScript("videoElement.muted = true;")
        } else if self.info.properties.mediaType == .youtube {
            webView.evaluateJavaScript("player.mute();")
        } else if self.info.properties.mediaType == .vimeo {
            webView.evaluateJavaScript("vimeoPlayer.setMuted(true);")
        }
    }

    @MainActor
    func unmuteMedias(webView: WKWebView) {
        if self.info.properties.mediaType == .video {
            webView.evaluateJavaScript("videoElement.muted = false;")
        } else if self.info.properties.mediaType == .youtube {
            webView.evaluateJavaScript("player.unMute();")
        } else if self.info.properties.mediaType == .vimeo {
            webView.evaluateJavaScript("vimeoPlayer.setMuted(false);")
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            self,
            isLoaded: $isLoaded,
            videoIdentifier: videoIdentifier,
            videoState: videoState,
            onMediaReady: onMediaReady
        )
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: MediaWebView
        var isLoaded: Binding<Bool>
        var videoIdentifier: String?
        var videoState: VideoState
        var onMediaReady: @MainActor () -> Void
        let challengeResolver: ChallengeResolver
        weak var webView: WKWebView?

        // Track previous values so updateUIView only reacts to real state changes,
        // not SwiftUI re-renders triggered by VideoState publishing.
        var lastIsVisible: Bool = false
        var lastIsLoaded: Bool = false
        var lastInProgress: Bool = true
        var isSystemPausing: Bool = false

        init(
            _ parent: MediaWebView,
            isLoaded: Binding<Bool>,
            videoIdentifier: String?,
            videoState: VideoState,
            resolver: ChallengeResolver = .shared,
            onMediaReady: @escaping @MainActor () -> Void) {

                self.parent = parent
                self.isLoaded = isLoaded
                self.videoIdentifier = videoIdentifier
                self.videoState = videoState
                self.onMediaReady = onMediaReady
                self.challengeResolver = resolver
            }

        @MainActor
        func registerWithVideoState() {
            guard let videoId = videoIdentifier,
                  videoState.shouldControl(videoIdentifier: videoId) else {
                return
            }

            videoState.register(
                videoIdentifier: videoId,
                play: { [weak self] in
                    guard let webView = self?.webView else { return }
                    self?.parent.playMedias(webView: webView)
                },
                pause: { [weak self] in
                    guard let webView = self?.webView else { return }
                    self?.parent.pauseMedias(webView: webView)
                },
                mute: { [weak self] in
                    guard let webView = self?.webView else { return }
                    self?.parent.muteMedias(webView: webView)
                },
                unmute: { [weak self] in
                    guard let webView = self?.webView else { return }
                    self?.parent.unmuteMedias(webView: webView)
                }
            )
        }

        @MainActor
        func unregisterFromVideoState() {
            guard let videoId = videoIdentifier else { return }
            videoState.unregister(videoIdentifier: videoId)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                isLoaded.wrappedValue = true
                self.webView = webView
                registerWithVideoState()
            }
        }

        func webView(_ webView: WKWebView, respondTo challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
            return await challengeResolver.resolve(challenge)
        }

        @MainActor
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let response = message.body as? String else {
                return
            }

            let canControlVideo = lastIsVisible && videoState.shouldControl(videoIdentifier: videoIdentifier)

            switch response {
            case "mediaReady":
                onMediaReady()
            case "playing" where canControlVideo:
                isSystemPausing = false
                videoState.updatePlayingState(true)
            case "paused" where canControlVideo:
                if !isSystemPausing {
                    videoState.updatePlayingState(false)
                }
            case "muted" where canControlVideo:
                if videoState.muteGroup.isMutedInitialized {
                    if !videoState.isMuted, let webView {
                        parent.unmuteMedias(webView: webView)
                    }
                } else {
                    videoState.updateMutedState(true)
                }
            case "unmuted" where canControlVideo:
                if videoState.muteGroup.isMutedInitialized {
                    if videoState.isMuted, let webView {
                        parent.muteMedias(webView: webView)
                    }
                } else {
                    videoState.updateMutedState(false)
                }
            default:
                break
            }
        }
    }
}

#endif
