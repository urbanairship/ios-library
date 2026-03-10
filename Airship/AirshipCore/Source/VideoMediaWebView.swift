/* Copyright Airship and Contributors */

#if !os(tvOS) && !os(watchOS)

import Foundation
import SwiftUI
import WebKit


@MainActor
private class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?

    init(_ delegate: WKScriptMessageHandler) {
        self.delegate = delegate
        super.init()
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

struct VideoMediaWebView: AirshipNativeViewRepresentable {

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
        contentController.add(WeakScriptMessageHandler(context.coordinator), name: "callback")

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
        config.mediaTypesRequiringUserActionForPlayback = []
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
        let isVisible = isVisible
        let isLoaded = isLoaded
        let inProgress = pagerState.inProgress
        Task { @MainActor [weak coordinator = context.coordinator] in
            coordinator?.update(
                isVisible: isVisible,
                isLoaded: isLoaded,
                inProgress: inProgress
            )
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
            if let videoID = Self.retrieveYoutubeVideoID(url: url) {
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
                      
                        <script src="https://player.vimeo.com/api/player.js"></script>
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

    static func retrieveYoutubeVideoID(url: String) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: "embed/([a-zA-Z0-9_-]+)")
            guard let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
                  let range = Range(match.range(at: 1), in: url) else {
                return nil
            }
            return String(url[range])
        } catch {
            return nil
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

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        private var parent: VideoMediaWebView
        private var isLoaded: Binding<Bool>
        private var videoIdentifier: String?
        private var videoState: VideoState
        private var onMediaReady: @MainActor () -> Void
        private let challengeResolver: ChallengeResolver
        private weak var webView: WKWebView?

        private var lastIsVisible: Bool = false
        private var lastIsLoaded: Bool = false
        private var lastInProgress: Bool = true

        /// Tracks whether the system (visibility change, pager, backgrounding) initiated a pause.
        /// When true, incoming "paused" JS callbacks won't clear `localIsPlaying`.
        private var isSystemPausing: Bool = false

        /// Tracks playing intent from JS callbacks. `nil` = initial (autoplay should trigger),
        /// `true` = playing/was playing, `false` = user explicitly paused.
        /// Guarded by `isSystemPausing` so system pauses don't clear user intent.
        private var localIsPlaying: Bool? = nil

        private var appStateTask: Task<Void, Never>?

        init(
            _ parent: VideoMediaWebView,
            isLoaded: Binding<Bool>,
            videoIdentifier: String?,
            videoState: VideoState,
            resolver: ChallengeResolver = .shared,
            onMediaReady: @escaping @MainActor () -> Void
        ) {
            self.parent = parent
            self.isLoaded = isLoaded
            self.videoIdentifier = videoIdentifier
            self.videoState = videoState
            self.onMediaReady = onMediaReady
            self.challengeResolver = resolver

            super.init()

            appStateTask = Task { @MainActor [weak self] in
                for await state in AppStateTracker.shared.stateUpdates {
                    guard !Task.isCancelled else { return }
                    if state == .active {
                        self?.handleForeground()
                    } else {
                        self?.systemPause()
                    }
                }
            }
        }

        deinit {
            appStateTask?.cancel()
            Task { @MainActor [weak videoState, weak webView, videoIdentifier] in
                if let videoIdentifier {
                    videoState?.unregister(videoIdentifier: videoIdentifier)
                }
                await webView?.pauseAllMediaPlayback()
            }
        }

        // MARK: - Playback Control

        @MainActor
        private var mediaType: ThomasViewInfo.Media.MediaType {
            parent.info.properties.mediaType
        }

        @MainActor
        private var isAutoplay: Bool {
            parent.video?.autoplay ?? false
        }

        @MainActor
        private var showControls: Bool {
            parent.video?.showControls ?? true
        }

        @MainActor
        private var autoResetPosition: Bool {
            parent.video?.autoResetPosition ?? (isAutoplay && !showControls)
        }

        @MainActor
        private var isMuted: Bool {
            parent.video?.muted ?? false
        }

        @MainActor
        private func play() {
            guard let webView else { return }
            switch mediaType {
            case .video:
                webView.evaluateJavaScript("videoElement.play();")
            case .youtube:
                webView.evaluateJavaScript("player.playVideo();")
            case .vimeo:
                webView.evaluateJavaScript("vimeoPlayer.play();")
            case .image:
                break
            }
        }

        @MainActor
        private func pause() {
            guard let webView else { return }
            switch mediaType {
            case .video:
                webView.evaluateJavaScript("videoElement.pause();")
            case .youtube:
                webView.evaluateJavaScript("player.pauseVideo();")
            case .vimeo:
                webView.evaluateJavaScript("vimeoPlayer.pause();")
            case .image: break
            }
        }

        @MainActor
        private func reset() {
            guard
                autoResetPosition,
                let webView
            else {
                return
            }

            switch mediaType {
            case .video:
                webView.evaluateJavaScript("videoElement.currentTime = 0;")
            case .youtube:
                webView.evaluateJavaScript("player.seekTo(0);")
            case .vimeo:
                webView.evaluateJavaScript("vimeoPlayer.setCurrentTime(0);")
            case .image:
                break
            }
        }

        @MainActor
        private func mute() {
            guard let webView else { return }
            switch mediaType {
            case .video:
                webView.evaluateJavaScript("videoElement.muted = true;")
            case .youtube:
                webView.evaluateJavaScript("player.mute();")
            case .vimeo:
                webView.evaluateJavaScript("vimeoPlayer.setMuted(true);")
            case .image:
                break
            }
        }

        @MainActor
        private func unmute() {
            guard let webView else { return }
            switch mediaType {
            case .video:
                webView.evaluateJavaScript("videoElement.muted = false;")
            case .youtube:
                webView.evaluateJavaScript("player.unMute();")
            case .vimeo:
                webView.evaluateJavaScript("vimeoPlayer.setMuted(false);")
            case .image:
                break
            }
        }

        // MARK: - State Management

        @MainActor
        func update(isVisible: Bool, isLoaded: Bool, inProgress: Bool) {
            let didChange = lastIsVisible != isVisible
                || lastIsLoaded != isLoaded
                || lastInProgress != inProgress
            lastIsVisible = isVisible
            lastIsLoaded = isLoaded
            lastInProgress = inProgress

            guard didChange else { return }

            if inProgress, isVisible, isLoaded {
                handleResume()
            } else {
                if !isVisible {
                    self.reset()
                }
                systemPause()
            }
        }

        @MainActor
        private func systemPause() {
            isSystemPausing = true
            pause()
        }

        @MainActor
        private func handleForeground() {
            guard lastIsVisible, lastIsLoaded, lastInProgress else { return }
            handleResume()
        }

        @MainActor
        private func handleResume() {
            let shouldPlay: Bool
            if videoState.shouldControl(videoIdentifier: videoIdentifier) {
                shouldPlay = videoState.isPlaying
            } else if isAutoplay {
                shouldPlay = localIsPlaying != false
            } else {
                shouldPlay = localIsPlaying == true
            }
            isSystemPausing = false
            if shouldPlay {
                localIsPlaying = true
                play()
            }
        }


        // MARK: - Video State Registration

        @MainActor
        private func registerWithVideoState() {
            guard let videoId = videoIdentifier,
                  videoState.shouldControl(videoIdentifier: videoId) else {
                return
            }

            videoState.register(
                videoIdentifier: videoId,
                play: { [weak self] in self?.play() },
                pause: { [weak self] in self?.pause() },
                mute: { [weak self] in self?.mute() },
                unmute: { [weak self] in self?.unmute() }
            )

            videoState.playGroup.initializePlaying(isAutoplay)
            videoState.muteGroup.initializeMuted(isMuted)
        }

        // MARK: - WKNavigationDelegate

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

        // MARK: - WKScriptMessageHandler

        @MainActor
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard let response = message.body as? String else {
                return
            }

            let canControlVideo = lastIsVisible && videoState.shouldControl(videoIdentifier: videoIdentifier)

            switch response {
            case "mediaReady":
                onMediaReady()
                if canControlVideo {
                    if videoState.isMuted { mute() } else { unmute() }
                }
            case "playing":
                if canControlVideo {
                    videoState.updatePlayingState(true)
                } else {
                    localIsPlaying = true
                }
            case "paused":
                if canControlVideo && !isSystemPausing {
                    videoState.updatePlayingState(false)
                } else if !isSystemPausing {
                    localIsPlaying = false
                }
            case "muted" where canControlVideo && showControls:
                videoState.updateMutedState(true)
            case "unmuted" where canControlVideo && showControls:
                videoState.updateMutedState(false)
            default:
                break
            }
        }
    }
}

#endif
