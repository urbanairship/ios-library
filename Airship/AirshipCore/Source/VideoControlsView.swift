/* Copyright Airship and Contributors */

#if !os(watchOS)

import SwiftUI
import AVFoundation
import AVKit
import Combine

@MainActor
private class VideoControlsObserver: ObservableObject {
    var timeObserver: Any?
    var endTimeObserver: (any NSObjectProtocol)?
    var statusObserver: NSKeyValueObservation?
    weak var player: AVPlayer?

    /// Called by wrapper
    internal func cleanup() {
        if let timeObserver = timeObserver, let player = player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil

        if let observer = endTimeObserver {
            NotificationCenter.default.removeObserver(observer)
            endTimeObserver = nil
        }
        statusObserver?.invalidate()
        statusObserver = nil
        player = nil
    }
}


#if !os(watchOS)
// The video control view wrapper for centering the controls over the video
struct VideoControlsWrapper: View {
    let info: ThomasViewInfo.Media
    let constraints: ViewConstraints
    let videoAspectRatio: CGFloat
    let onMediaReady: @MainActor () -> Void

    @State private var hasError: Bool = false
    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 1.0
    @State private var isControlsVisible: Bool = true
    @State private var controlsTimer: Timer?

    private var showControls: Bool {
        info.properties.video?.showControls ?? true
    }

    var body: some View {
        ThomasVideoPlayer(
            info: info,
            onMediaReady: onMediaReady,
            hasError: $hasError,
            player: $player
        )
        .airshipApplyIf(self.constraints.width == nil || self.constraints.height == nil) {
            $0.aspectRatio(videoAspectRatio, contentMode: ContentMode.fill)
        }
        .fitVideo(
            mediaFit: self.info.properties.mediaFit,
            cropPosition: self.info.properties.cropPosition,
            constraints: constraints,
            videoAspectRatio: videoAspectRatio
        )
        .modifier(VideoControls(
            hasError: hasError,
            showControls: showControls,
            player: player,
            isPlaying: $isPlaying,
            currentTime: $currentTime,
            duration: $duration,
            isControlsVisible: $isControlsVisible,
            controlsTimer: $controlsTimer
        ))
    }
}

#endif

internal struct VideoControls: ViewModifier {
    let hasError: Bool
    let showControls: Bool
    let player: AVPlayer?
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var isControlsVisible: Bool
    @Binding var controlsTimer: Timer?

    @StateObject private var observer = VideoControlsObserver()
    @State private var isDraggingSlider: Bool = false

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    ZStack {
                        if hasError {
                            VideoErrorView()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                        } else if showControls && isControlsVisible && player?.currentItem?.status == .readyToPlay {
                            VideoControlsView(
                                player: player,
                                isPlaying: $isPlaying,
                                currentTime: $currentTime,
                                duration: $duration,
                                isDraggingSlider: $isDraggingSlider,
                                size: geometry.size,
                                onInteraction: resetHideTimer
                            )
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .transition(.opacity)
                        }
                    }
                }
                    .allowsHitTesting(hasError || (showControls && isControlsVisible))
            )
            .onTapGesture {
                if showControls && !hasError {
                    toggleControlsVisibility()
                }
            }
            .onAppear {
                setupPlayerObservers()
                if showControls {
                    startHideTimer()
                }
            }
            .onDisappear {
                cleanup()
                /// Do final observer cleanup
                observer.cleanup()
            }
            .airshipOnChangeOf(player) { _ in
                cleanup()
                setupPlayerObservers()
                if showControls {
                    startHideTimer()
                }
            }
    }

    private func toggleControlsVisibility() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isControlsVisible.toggle()
        }

        if isControlsVisible {
            startHideTimer()
        } else {
            controlsTimer?.invalidate()
        }
    }

    private func resetHideTimer() {
        if isControlsVisible {
            startHideTimer()
        }
    }

    private func startHideTimer() {
        controlsTimer?.invalidate()

        let visibilityBinding = _isControlsVisible
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.3)) {
                    visibilityBinding.wrappedValue = false
                }
            }
        }
    }

    private func setupPlayerObservers() {
        guard let player = player else { return }

        observer.cleanup()
        observer.player = player

        let isPlayingBinding = _isPlaying
        let currentTimeBinding = _currentTime
        let durationBinding = _duration
        let isDraggingBinding = _isDraggingSlider

        observer.endTimeObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            Task { @MainActor in
                isPlayingBinding.wrappedValue = false
                player.seek(to: .zero)
            }
        }
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        observer.timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            Task { @MainActor in
                if !isDraggingBinding.wrappedValue {
                    currentTimeBinding.wrappedValue = time.seconds
                }

                isPlayingBinding.wrappedValue = player.rate > 0

                if let currentItem = player.currentItem {
                    let duration = currentItem.duration
                    if duration.isNumeric && !duration.isIndefinite {
                        durationBinding.wrappedValue = duration.seconds
                    }
                }
            }
        }
        isPlaying = player.rate > 0
        if let currentItem = player.currentItem {
            let duration = currentItem.duration
            if duration.isNumeric && !duration.isIndefinite {
                self.duration = duration.seconds
            }
        }

        if let currentItem = player.currentItem {
            let currentTime = currentItem.currentTime()
            if currentTime.isNumeric {
                self.currentTime = currentTime.seconds
            }
        }
        observer.statusObserver = player.currentItem?.observe(\.status, options: [.new, .initial]) { item, _ in
            Task { @MainActor in
                if item.status == .readyToPlay {
                    let duration = item.duration
                    if duration.isNumeric && !duration.isIndefinite {
                        durationBinding.wrappedValue = duration.seconds
                    }

                    let currentTime = item.currentTime()
                    if currentTime.isNumeric {
                        currentTimeBinding.wrappedValue = currentTime.seconds
                    }

                    isPlayingBinding.wrappedValue = player.rate > 0
                }
            }
        }
    }

    private func cleanup() {
        controlsTimer?.invalidate()
        controlsTimer = nil
        observer.cleanup()
    }

}

private struct VideoErrorView: View {
    var body: some View {
        Color.black
            .overlay(
                Image(systemName: "play.slash.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.5))
            )
    }
}

private struct VideoControlsView: View {
    let player: AVPlayer?
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var isDraggingSlider: Bool
    let size: CGSize
    let onInteraction: () -> Void

    @State private var isMuted: Bool = false

    private var scaleFactor: CGFloat {
        let baseControlsWidth: CGFloat = 320
        let baseControlsHeight: CGFloat = 180

        let widthScale = size.width / baseControlsWidth
        let heightScale = size.height / baseControlsHeight

        let scale = min(widthScale, heightScale, 1.0)

        return max(scale, 0.2)
    }

    private var centerControlSize: CGFloat {
        50 * scaleFactor
    }

    private var skipButtonSize: CGFloat {
        30 * scaleFactor
    }

    private var controlSpacing: CGFloat {
        60 * scaleFactor
    }

    private var controlPadding: CGFloat {
        40 * scaleFactor
    }

    private var fontSize: CGFloat {
        14 * scaleFactor
    }

    private var iconSize: CGFloat {
        18 * scaleFactor
    }

    private var bottomBarPadding: CGFloat {
        12 * scaleFactor
    }

    private var progressBarSpacing: CGFloat {
        10 * scaleFactor
    }

    private var cornerRadius: CGFloat {
        20 * scaleFactor
    }

    private var playButtonPadding: CGFloat {
        15 * scaleFactor
    }

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())

            VStack(spacing: 0) {
                Spacer()

                HStack(spacing: controlSpacing) {
                    Button(action: {
                        skipBackward()
                        onInteraction()
                    }) {
                        Image(systemName: "gobackward.15")
                            .font(.system(size: skipButtonSize))
                            .foregroundColor(.white)
                    }

                    Button(action: {
                        togglePlayPause()
                        onInteraction()
                    }) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: centerControlSize))
                            .foregroundColor(.white)
                    }

                    Button(action: {
                        skipForward()
                        onInteraction()
                    }) {
                        Image(systemName: "goforward.15")
                            .font(.system(size: skipButtonSize))
                            .foregroundColor(.white)
                    }
                }
                .padding(controlPadding)
                .background(Color.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

                Spacer()
                VStack(spacing: progressBarSpacing) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2 * scaleFactor)
                                .fill(Color.white.opacity(0.3))
                                .frame(height: 4 * scaleFactor)
                                .frame(maxHeight: .infinity)

                            RoundedRectangle(cornerRadius: 2 * scaleFactor)
                                .fill(Color.white)
                                .frame(width: max(0, (duration > 0 ? CGFloat(currentTime / duration) : 0) * geometry.size.width), height: 4 * scaleFactor)
                                .frame(maxHeight: .infinity)

                            Circle()
                                .fill(Color.white)
                                .frame(width: 12 * scaleFactor, height: 12 * scaleFactor)
                                .position(
                                    x: max(6 * scaleFactor, min(geometry.size.width - 6 * scaleFactor, (duration > 0 ? CGFloat(currentTime / duration) : 0) * geometry.size.width)),
                                    y: geometry.size.height / 2
                                )
                        }
                        .contentShape(Rectangle())
                        #if os(tvOS)
                        .focusable()
                        .onMoveCommand { direction in
                            let stepSize: Double = 5.0 // 5 second steps
                            switch direction {
                            case .left:
                                let newTime = max(0, currentTime - stepSize)
                                currentTime = newTime
                                seek(to: newTime)
                                onInteraction()
                            case .right:
                                let newTime = min(duration, currentTime + stepSize)
                                currentTime = newTime
                                seek(to: newTime)
                                onInteraction()
                            default:
                                break
                            }
                        }
                        #else
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDraggingSlider = true
                                    let progress = max(0, min(1, value.location.x / geometry.size.width))
                                    currentTime = progress * duration
                                    player?.pause()
                                    onInteraction()
                                }
                                .onEnded { _ in
                                    isDraggingSlider = false
                                    seek(to: currentTime)
                                    if isPlaying {
                                        player?.play()
                                    }
                                    onInteraction()
                                }
                        )
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    let progress = max(0, min(1, value.location.x / geometry.size.width))
                                    currentTime = progress * duration
                                    seek(to: currentTime)
                                    onInteraction()
                                }
                        )
                        #endif
                    }
                    .frame(height: max(20 * scaleFactor, 20))
                    HStack {
                        Text(formatTime(currentTime))
                            .font(.system(size: fontSize))
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .lineLimit(1)

                        Spacer()

                        Text("-\(formatTime(max(0, duration - currentTime)))")
                            .font(.system(size: fontSize))
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .lineLimit(1)

                        Button(action: {
                            toggleMute()
                            onInteraction()
                        }) {
                            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: iconSize))
                                .foregroundColor(.white)
                                .frame(width: iconSize * 1.5, height: iconSize * 1.5)
                        }
                    }
                }
                .padding(bottomBarPadding)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.black.opacity(0), Color.black.opacity(0.8)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .onAppear {
            if let player = player {
                isMuted = player.isMuted
            }
        }
    }

    private func togglePlayPause() {
        guard let player = player else { return }

        if isPlaying {
            player.pause()
        } else {
            player.play()
        }

        isPlaying = player.rate > 0
    }

    private func seek(to time: Double) {
        guard let player = player else { return }

        let targetTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func skipBackward() {
        let newTime = max(currentTime - 15, 0)
        seek(to: newTime)
    }

    private func skipForward() {
        let newTime = min(currentTime + 15, duration)
        seek(to: newTime)
    }

    private func toggleMute() {
        guard let player = player else { return }
        player.isMuted.toggle()
        isMuted = player.isMuted
    }

    private func formatTime(_ interval: TimeInterval, locale: Locale = Locale.current) -> String {
        if interval.isNaN || interval.isInfinite {
            return "--:--"
        }

        let effectiveInterval = max(0, interval)

        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional // Results in "HH:MM:SS" or "MM:SS"
        formatter.zeroFormattingBehavior = .pad // Ensures padding like "01:05" instead of "1:5"

        let showsHours: Bool
        if effectiveInterval >= 3600.0 { // 3600 seconds = 1 hour
            showsHours = true
            formatter.allowedUnits = [.hour, .minute, .second]
        } else {
            showsHours = false
            formatter.allowedUnits = [.minute, .second]
        }

        var calendar = Calendar.current
        calendar.locale = locale
        formatter.calendar = calendar

        return formatter.string(from: effectiveInterval) ?? (showsHours ? "00:00:00" : "00:00")
    }

}


#endif
