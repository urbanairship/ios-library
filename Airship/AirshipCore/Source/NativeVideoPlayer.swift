/* Copyright Airship and Contributors */

#if !os(watchOS) && !os(macOS)

import Foundation
import SwiftUI
import AVKit
import AVFoundation
import UIKit

@MainActor
struct NativeVideoPlayer: UIViewRepresentable {
    typealias UIViewType = UIView

    let info: ThomasViewInfo.Media
    let videoIdentifier: String?
    let onMediaReady: @MainActor () -> Void

    @Binding var hasError: Bool
    @Binding var player: AVPlayer?

    @Environment(\.isVisible) private var isVisible
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var isLoaded: Bool = false
    @EnvironmentObject var pagerState: PagerState
    @EnvironmentObject var videoState: VideoState

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
            Task { @MainActor in
                self.hasError = true
            }
            return playerContainer
        }

        let playerItem = AVPlayerItem(url: videoURL)
        let playerInstance = AVPlayer(playerItem: playerItem)

        playerContainer.player = playerInstance
        playerContainer.videoURL = videoURL
        playerContainer.shouldLoop = video?.loop ?? false
        playerContainer.isMuted = video?.muted ?? false
        playerContainer.configurePlayerView()

        Task { @MainActor in
            self.player = playerInstance
        }

        context.coordinator.configure(
            playerContainer: playerContainer,
            onMediaReady: onMediaReady
        )

        return playerContainer
    }

    @MainActor
    func updateUIView(_ uiView: UIView, context: Context) {
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

    func makeCoordinator() -> Coordinator {
        Coordinator(
            isLoaded: $isLoaded,
            hasError: $hasError,
            videoState: videoState,
            videoIdentifier: videoIdentifier,
            isAutoplay: video?.autoplay ?? false,
            showControls: video?.showControls ?? true,
            autoResetPosition: video?.autoResetPosition ?? ((video?.autoplay ?? false) && !(video?.showControls ?? true))
        )
    }

    // MARK: - PlayerObservers

    private final class PlayerObservers: @unchecked Sendable {
        var endTimeObserver: (any NSObjectProtocol)?
        var statusObserver: NSKeyValueObservation?
        var rateObserver: NSKeyValueObservation?
        var muteObserver: NSKeyValueObservation?
        weak var player: AVPlayer?

        func cleanup() {
            if let observer = endTimeObserver {
                NotificationCenter.default.removeObserver(observer)
                endTimeObserver = nil
            }
            statusObserver?.invalidate()
            statusObserver = nil
            rateObserver?.invalidate()
            rateObserver = nil
            muteObserver?.invalidate()
            muteObserver = nil
        }
    }

    // MARK: - Coordinator

    @MainActor
    class Coordinator: NSObject {
        private var isLoaded: Binding<Bool>
        private var hasError: Binding<Bool>
        private var videoState: VideoState
        private var videoIdentifier: String?
        private var isAutoplay: Bool
        private var showControls: Bool
        private var autoResetPosition: Bool

        private weak var playerContainer: VideoPlayerContainer?
        private var onMediaReady: (@MainActor () -> Void)?
        private let observers = PlayerObservers()

        private var lastIsVisible: Bool = false
        private var lastIsLoaded: Bool = false
        private var lastInProgress: Bool = true

        /// Tracks whether the system (visibility change, pager, backgrounding) initiated a pause.
        /// When true, incoming rate changes from AVPlayer won't clear `localIsPlaying`.
        private var isSystemPausing: Bool = false

        /// Tracks playing intent from AVPlayer rate changes. `nil` = initial (autoplay should trigger),
        /// `true` = playing/was playing, `false` = user explicitly paused.
        /// Guarded by `isSystemPausing` so system pauses don't clear user intent.
        private var localIsPlaying: Bool? = nil

        private var appStateTask: Task<Void, Never>?

        init(
            isLoaded: Binding<Bool>,
            hasError: Binding<Bool>,
            videoState: VideoState,
            videoIdentifier: String?,
            isAutoplay: Bool,
            showControls: Bool,
            autoResetPosition: Bool
        ) {
            self.isLoaded = isLoaded
            self.hasError = hasError
            self.videoState = videoState
            self.videoIdentifier = videoIdentifier
            self.isAutoplay = isAutoplay
            self.showControls = showControls
            self.autoResetPosition = autoResetPosition

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
            let observers = self.observers
            let videoState = self.videoState
            let videoIdentifier = self.videoIdentifier
            Task { @MainActor in
                observers.player?.pause()
                observers.cleanup()
                if let videoIdentifier {
                    videoState.unregister(videoIdentifier: videoIdentifier)
                }
            }
        }

        // MARK: - Configuration

        @MainActor
        func configure(
            playerContainer: VideoPlayerContainer,
            onMediaReady: @MainActor @escaping () -> Void
        ) {
            cleanupObservers()
            self.playerContainer = playerContainer
            self.onMediaReady = onMediaReady
            setupObservers()
            registerWithVideoState()
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

            playerContainer?.alpha = hasError.wrappedValue ? 0 : 1

            guard didChange else { return }

            if inProgress, isVisible, isLoaded {
                handleResume()
            } else {
                if !isVisible {
                    self.resetToBeginning()
                }
                systemPause()
            }
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
                playerContainer?.player?.play()
            }
        }

        @MainActor
        private func systemPause() {
            isSystemPausing = true
            playerContainer?.player?.pause()
        }

        @MainActor
        private func resetToBeginning() {
            guard autoResetPosition else { return }
            localIsPlaying = nil
            playerContainer?.player?.seek(to: .zero)
        }

        @MainActor
        private func handleForeground() {
            guard lastIsVisible, lastIsLoaded, lastInProgress else { return }
            handleResume()
        }

        // MARK: - Video State Registration

        @MainActor
        private func registerWithVideoState() {
            guard let videoId = videoIdentifier,
                  videoState.shouldControl(videoIdentifier: videoId),
                  let player = playerContainer?.player else {
                return
            }

            videoState.register(
                videoIdentifier: videoId,
                play: { [weak player] in player?.play() },
                pause: { [weak player] in player?.pause() },
                mute: { [weak player] in player?.isMuted = true },
                unmute: { [weak player] in player?.isMuted = false }
            )

            videoState.muteGroup.initializeMuted(player.isMuted)
            videoState.playGroup.initializePlaying(isAutoplay || player.rate > 0)
            player.isMuted = videoState.isMuted
        }

        // MARK: - Observers

        @MainActor
        private func setupObservers() {
            guard let playerContainer = playerContainer,
                  let player = playerContainer.player else { return }

            let shouldLoop = playerContainer.shouldLoop
            observers.player = player

            observers.endTimeObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [weak player] _ in
                Task { @MainActor in
                    if shouldLoop {
                        player?.seek(to: .zero)
                        player?.play()
                    }
                }
            }

            if let playerItem = player.currentItem {
                let isLoadedBinding = isLoaded
                let hasErrorBinding = hasError
                let onReady = onMediaReady

                observers.statusObserver = playerItem.observe(\.status, options: [.new]) { item, _ in
                    Task { @MainActor in
                        switch item.status {
                        case .readyToPlay:
                            isLoadedBinding.wrappedValue = true
                            hasErrorBinding.wrappedValue = false
                            onReady?()
                        case .failed:
                            hasErrorBinding.wrappedValue = true
                        case .unknown:
                            break
                        @unknown default:
                            break
                        }
                    }
                }
            }

            observers.muteObserver = player.observe(\.isMuted, options: [.new]) { [weak self] player, _ in
                Task { @MainActor in
                    guard let self else { return }
                    let canControlVideo = self.lastIsVisible
                        && self.videoState.shouldControl(videoIdentifier: self.videoIdentifier)
                        && self.showControls
                    if canControlVideo {
                        self.videoState.updateMutedState(player.isMuted)
                    }
                }
            }

            observers.rateObserver = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
                Task { @MainActor in
                    guard let self else { return }
                    let isPlaying = player.timeControlStatus == .playing
                    let isPaused = player.timeControlStatus == .paused

                    let canControlVideo = self.lastIsVisible
                        && self.videoState.shouldControl(videoIdentifier: self.videoIdentifier)

                    if canControlVideo {
                        if isPlaying {
                            self.isSystemPausing = false
                            self.videoState.updatePlayingState(true)
                        } else if isPaused && !self.isSystemPausing {
                            self.videoState.updatePlayingState(false)
                        }
                    } else {
                        if isPlaying {
                            self.localIsPlaying = true
                        } else if isPaused && !self.isSystemPausing {
                            self.localIsPlaying = false
                        }
                    }
                }
            }
        }

        @MainActor
        private func cleanupObservers() {
            observers.cleanup()
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
