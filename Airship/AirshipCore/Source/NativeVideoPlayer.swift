/* Copyright Airship and Contributors */

#if !os(watchOS) && !os(macOS)

import Foundation
import SwiftUI
import AVKit
import AVFoundation
import UIKit

struct NativeVideoPlayer: UIViewRepresentable {
    typealias UIViewType = UIView

    let info: ThomasViewInfo.Media
    let onMediaReady: @MainActor () -> Void

    @Binding
    var hasError: Bool
    @Binding
    var player: AVPlayer?
    @Binding
    var isSystemPausing: Bool

    @Environment(\.isVisible)
    private var isVisible
    @Environment(\.pageIdentifier)
    private var pageIdentifier
    @Environment(\.layoutDirection)
    private var layoutDirection

    @State
    private var isLoaded: Bool = false

    @EnvironmentObject
    var pagerState: PagerState
    @EnvironmentObject
    var videoState: VideoState

    private var video: ThomasViewInfo.Media.Video? {
        self.info.properties.video
    }

    private var url: String {
        self.info.properties.url
    }

    @MainActor
    func makeUIView(context: Context) -> UIView {
        let playerContainer = VideoPlayerContainer(frame: .zero)
        playerContainer.isAccessibilityElement = true
        playerContainer.accessibilityLabel = self.info.accessible.contentDescription
        playerContainer.info = self.info
        playerContainer.isRTL = layoutDirection == .rightToLeft

        guard let videoURL = URL(string: url) else {
            // Invalid URL - set error state immediately
            Task { @MainActor in
                self.hasError = true
            }
            return playerContainer
        }

        // Set up AVPlayer
        let playerItem = AVPlayerItem(url: videoURL)
        let playerInstance = AVPlayer(playerItem: playerItem)

        // Configure player container
        playerContainer.player = playerInstance
        playerContainer.videoURL = videoURL

        Task { @MainActor in
            self.player = playerInstance
        }

        let videoSettings = self.video
        playerContainer.shouldLoop = videoSettings?.loop ?? false
        playerContainer.isMuted = videoSettings?.muted ?? false

        // Set up observers
        setupObservers(container: playerContainer, context: context)

        // Finalize player setup
        playerContainer.configurePlayerView()

        return playerContainer
    }

    @MainActor
    func updateUIView(_ uiView: UIView, context: Context) {
        Task { @MainActor [weak uiView] in
            guard let playerContainer = uiView as? VideoPlayerContainer else {
                return
            }

            self.updateState(
                playerContainer: playerContainer,
                coordinator: context.coordinator
            )
        }
    }

    @MainActor
    private func updateState(
        playerContainer: VideoPlayerContainer,
        coordinator: Coordinator
    ) {
        let justLoaded = !coordinator.lastIsLoaded && isLoaded
        let didChange = coordinator.lastIsVisible != isVisible
            || coordinator.lastIsLoaded != isLoaded
            || coordinator.lastInProgress != pagerState.inProgress
        coordinator.lastIsVisible = isVisible
        coordinator.lastIsLoaded = isLoaded
        coordinator.lastInProgress = pagerState.inProgress

        guard didChange else { return }

        playerContainer.alpha = hasError ? 0 : 1

        let isCurrentlyPlaying = (playerContainer.player?.rate ?? 0) > 0
        let isAutoplay = video?.autoplay ?? false

        if pagerState.inProgress {
            switch (isVisible, isLoaded) {
            case (true, true):
                let shouldPlay = videoState.isPlaying
                    || (isAutoplay && (pageIdentifier != nil || justLoaded))
                if shouldPlay {
                    self.isSystemPausing = false
                    videoState.updatePlayingState(true)
                    playerContainer.player?.play()
                }
            case (false, true):
                if isCurrentlyPlaying { self.isSystemPausing = true }
                if isAutoplay {
                    playerContainer.player?.seek(to: CMTime.zero)
                }
                playerContainer.player?.pause()
            default:
                if isCurrentlyPlaying { self.isSystemPausing = true }
                playerContainer.player?.pause()
            }
        } else {
            if isCurrentlyPlaying { self.isSystemPausing = true }
            playerContainer.player?.pause()
        }
    }

    @MainActor
    private func setupObservers(container: VideoPlayerContainer, context: Context) {
        context.coordinator.cleanup()
        context.coordinator.playerContainer = container
        context.coordinator.onMediaReady = onMediaReady

        let shouldLoop = container.shouldLoop
        let player = container.player

        context.coordinator.endTimeObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { [weak player] _ in
            Task { @MainActor in
                if shouldLoop {
                    player?.seek(to: CMTime.zero)
                    player?.play()
                }
            }
        }

        if let playerItem = container.player?.currentItem {
            let isLoaded = context.coordinator.isLoaded
            let hasError = context.coordinator.hasError
            let onReady = context.coordinator.onMediaReady

            context.coordinator.statusObserver = playerItem.observe(\.status, options: [.new]) { item, _ in
                Task { @MainActor in
                    switch item.status {
                    case .readyToPlay:
                        isLoaded.wrappedValue = true
                        hasError.wrappedValue = false
                        onReady?()
                    case .failed:
                        hasError.wrappedValue = true
                    case .unknown:
                        break
                    @unknown default:
                        break
                    }
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoaded: $isLoaded, hasError: $hasError)
    }

    class Coordinator: NSObject {
        var isLoaded: Binding<Bool>
        var hasError: Binding<Bool>
        var playerContainer: VideoPlayerContainer?
        var onMediaReady: (@MainActor () -> Void)?
        var endTimeObserver: (any NSObjectProtocol)?
        var statusObserver: NSKeyValueObservation?
        var lastIsVisible: Bool = false
        var lastIsLoaded: Bool = false
        var lastInProgress: Bool = true

        init(isLoaded: Binding<Bool>, hasError: Binding<Bool>) {
            self.isLoaded = isLoaded
            self.hasError = hasError
            super.init()
        }

        func cleanup() {
            if let observer = endTimeObserver {
                NotificationCenter.default.removeObserver(observer)
                endTimeObserver = nil
            }
            statusObserver?.invalidate()
            statusObserver = nil
        }

        deinit {
            cleanup()
        }

    }

    // MARK: - VideoPlayerContainer

    class VideoPlayerContainer: UIView {
        var player: AVPlayer?
        var videoURL: URL?
        var shouldLoop: Bool = false
        var isMuted: Bool = false
        var info: ThomasViewInfo.Media?
        var isRTL: Bool = false

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func configurePlayerView() {
            layer.sublayers?.forEach {
                if $0 is AVPlayerLayer {
                    $0.removeFromSuperlayer()
                }
            }

            setupPlayer()

            player?.isMuted = isMuted
        }

        func setupPlayer() {
            guard let player = self.player else { return }

            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.frame = bounds

            if let mediaInfo = self.info {
                playerLayer.videoGravity = videoGravityForMediaFit(mediaInfo.properties.mediaFit)
            } else {
                playerLayer.videoGravity = videoGravityForMediaFit(.centerInside)
            }

            layer.addSublayer(playerLayer)
        }

        func videoGravityForMediaFit(_ mediaFit: ThomasMediaFit) -> AVLayerVideoGravity {
            switch mediaFit {
            case .centerInside:
                return .resizeAspect
            case .center:
                // AVLayerVideoGravity doesn't have a direct .center equivalent
                return .resize
            case .fitCrop, .centerCrop:
                return .resizeAspectFill
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()

            if let playerLayer = layer.sublayers?.first(where: { $0 is AVPlayerLayer }) as? AVPlayerLayer {
                playerLayer.frame = bounds
            }
        }
    }
}

#endif
