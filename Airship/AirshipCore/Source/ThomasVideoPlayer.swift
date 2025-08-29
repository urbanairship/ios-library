/* Copyright Airship and Contributors */

#if !os(watchOS)

import Foundation
import SwiftUI
import AVKit
import AVFoundation
import UIKit

struct ThomasVideoPlayer: UIViewRepresentable {
    typealias UIViewType = UIView

    let info: ThomasViewInfo.Media
    let onMediaReady: @MainActor () -> Void
    @Binding var hasError: Bool
    @Binding var player: AVPlayer?
    @Environment(\.isVisible) private var isVisible
    @State private var isLoaded: Bool = false
    @EnvironmentObject var pagerState: PagerState
    @Environment(\.layoutDirection) private var layoutDirection

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

        DispatchQueue.main.async {
            self.player = playerInstance
        }

        let videoSettings = self.video
        playerContainer.showControls = false
        playerContainer.shouldLoop = videoSettings?.loop ?? false
        playerContainer.shouldAutoplay = videoSettings?.autoplay ?? false
        playerContainer.isMuted = videoSettings?.muted ?? false

        // Set up observers
        setupObservers(container: playerContainer, context: context)

        // Finalize player setup
        playerContainer.configurePlayerView()

        return playerContainer
    }

    @MainActor
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let playerContainer = uiView as? VideoPlayerContainer else { return }

        if hasError {
            playerContainer.alpha = 0
        } else {
            playerContainer.alpha = 1
        }

        if (pagerState.inProgress) {
            switch (isVisible, isLoaded) {
            case (true, true):
                handleAutoplayingVideos(container: playerContainer)
            case (false, true):
                resetMedias(container: playerContainer)
                pauseMedias(container: playerContainer)
            default:
                pauseMedias(container: playerContainer)
            }
        } else {
            pauseMedias(container: playerContainer)
        }
    }

    @MainActor
    private func setupObservers(container: VideoPlayerContainer, context: Context) {
        // Register for playback status notifications
        let shouldLoop = container.shouldLoop
        let player = container.player

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { _ in
            Task { @MainActor in
                if shouldLoop {
                    player?.seek(to: CMTime.zero)
                    player?.play()
                }
            }
        }

        // Monitor readiness
        container.player?.currentItem?.addObserver(
            context.coordinator,
            forKeyPath: "status",
            options: [.new],
            context: nil
        )

        // Save references for coordinator
        context.coordinator.playerContainer = container
        context.coordinator.onMediaReady = onMediaReady
    }

    @MainActor
    func handleAutoplayingVideos(container: VideoPlayerContainer) {
        if isVisible {
            if video?.autoplay ?? false {
                playMedias(container: container)
            }
        } else {
            pauseMedias(container: container)
        }
    }

    @MainActor
    func pauseMedias(container: VideoPlayerContainer) {
        container.player?.pause()
    }

    @MainActor
    func resetMedias(container: VideoPlayerContainer) {
        if video?.autoplay ?? false {
            container.player?.seek(to: CMTime.zero)
        }
    }

    @MainActor
    func playMedias(container: VideoPlayerContainer) {
        container.player?.play()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoaded: $isLoaded, hasError: $hasError)
    }

    class Coordinator: NSObject {
        var isLoaded: Binding<Bool>
        var hasError: Binding<Bool>
        var playerContainer: VideoPlayerContainer?
        var onMediaReady: (@MainActor () -> Void)?

        init(isLoaded: Binding<Bool>, hasError: Binding<Bool>) {
            self.isLoaded = isLoaded
            self.hasError = hasError
            super.init()
        }

        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            guard keyPath == "status",
                  let playerItem = object as? AVPlayerItem else {
                return
            }

            switch playerItem.status {
            case .readyToPlay:
                let onReady = self.onMediaReady
                let isLoaded = self.isLoaded
                let hasError = self.hasError

                Task { @MainActor in
                    isLoaded.wrappedValue = true
                    hasError.wrappedValue = false
                    onReady?()
                }
            case .failed:
                let hasError = self.hasError
                Task { @MainActor in
                    hasError.wrappedValue = true
                }
            case .unknown:
                break
            @unknown default:
                break
            }
        }
    }

    // MARK: - VideoPlayerContainer

    class VideoPlayerContainer: UIView {
        var player: AVPlayer?
        var playerViewController: AVPlayerViewController?
        var videoURL: URL?
        var showControls: Bool = true
        var shouldLoop: Bool = false
        var shouldAutoplay: Bool = false
        var isMuted: Bool = false
        var info: ThomasViewInfo.Media?
        var isRTL: Bool = false
        private var playerLayerObservation: NSKeyValueObservation?

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func configurePlayerView() {
            // Remove existing views
            subviews.forEach { $0.removeFromSuperview() }
            layer.sublayers?.forEach {
                if $0 is AVPlayerLayer {
                    $0.removeFromSuperlayer()
                }
            }

            if showControls {
                setupPlayerWithControls()
            } else {
                setupPlayer()
            }

            // Configure player
            player?.isMuted = isMuted

            // Start playback if needed
            if shouldAutoplay {
                player?.play()
            }
        }

        func setupPlayerWithControls() {
            guard let player = self.player else { return }

            let playerViewController = AVPlayerViewController()
            playerViewController.player = player
            playerViewController.showsPlaybackControls = false

            if let mediaInfo = self.info {
                playerViewController.videoGravity = videoGravityForMediaFit(mediaInfo.properties.mediaFit)
            } else {
                playerViewController.videoGravity = videoGravityForMediaFit(.centerInside)
            }

            let hostingController = UIHostingController(rootView: EmptyView())
            hostingController.view.backgroundColor = .clear
            hostingController.view.frame = bounds
            hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

            hostingController.addChild(playerViewController)
            hostingController.view.addSubview(playerViewController.view)
            playerViewController.view.frame = hostingController.view.bounds
            playerViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            playerViewController.didMove(toParent: hostingController)

            addSubview(hostingController.view)

            self.playerViewController = playerViewController
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
