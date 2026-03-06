/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

/// State class managing video playback state within a VideoController scope.
@MainActor
class VideoState: ObservableObject {
    /// The unique identifier for this video controller
    let identifier: String

    /// Optional array of video identifiers to control. If nil, controls all videos.
    let videoScope: [String]?

    /// Shared group container that flows through the VideoState chain.
    let videoGroups: VideoGroups

    let muteGroup: VideoGroupState
    let playGroup: VideoGroupState

    var isPlaying: Bool { playGroup.isPlaying }
    var isMuted: Bool { muteGroup.isMuted }

    var isPlayingPublisher: AnyPublisher<Bool, Never> {
        playGroup.$isPlaying.eraseToAnyPublisher()
    }

    var isMutedPublisher: AnyPublisher<Bool, Never> {
        muteGroup.$isMuted.eraseToAnyPublisher()
    }

    /// Registry of video callbacks
    private var registeredVideos: [String: VideoRegistration] = [:]
    private var subscriptions: Set<AnyCancellable> = Set()

    struct VideoRegistration {
        let play: @MainActor () -> Void
        let pause: @MainActor () -> Void
        let mute: @MainActor () -> Void
        let unmute: @MainActor () -> Void
    }

    init(
        identifier: String,
        videoScope: [String]? = nil,
        videoGroups: VideoGroups = VideoGroups(),
        muteGroup: VideoGroupState = VideoGroupState(),
        playGroup: VideoGroupState = VideoGroupState()
    ) {
        self.identifier = identifier
        self.videoScope = videoScope
        self.videoGroups = videoGroups
        self.muteGroup = muteGroup
        self.playGroup = playGroup

        setupGroupSync()
    }

    /// False when this is the default fallback state injected at the root with no real VideoController ancestor.
    private var hasController: Bool {
        guard !identifier.isEmpty else {
            AirshipLogger.warn("Video control behaviors require a video_controller ancestor")
            return false
        }
        return true
    }

    /// Determines if this controller should control a video with the given identifier
    func shouldControl(videoIdentifier: String?) -> Bool {
        guard let scope = videoScope else {
            return true
        }
        guard let videoId = videoIdentifier else {
            return false
        }
        return scope.contains(videoId)
    }

    /// Register a video with its control callbacks
    func register(
        videoIdentifier: String,
        play: @escaping @MainActor () -> Void,
        pause: @escaping @MainActor () -> Void,
        mute: @escaping @MainActor () -> Void,
        unmute: @escaping @MainActor () -> Void
    ) {
        guard shouldControl(videoIdentifier: videoIdentifier) else { return }

        registeredVideos[videoIdentifier] = VideoRegistration(
            play: play,
            pause: pause,
            mute: mute,
            unmute: unmute
        )
    }

    /// Unregister a video
    func unregister(videoIdentifier: String) {
        registeredVideos.removeValue(forKey: videoIdentifier)
    }

    // MARK: - Playback Control

    func play() {
        guard hasController else { return }
        registeredVideos.values.forEach { $0.play() }
        playGroup.isPlaying = true
    }

    func pause() {
        guard hasController else { return }
        registeredVideos.values.forEach { $0.pause() }
        playGroup.isPlaying = false
    }

    func togglePlay() {
        guard hasController else { return }
        if isPlaying { pause() } else { play() }
    }

    // MARK: - Mute Control

    func mute() {
        guard hasController else { return }
        registeredVideos.values.forEach { $0.mute() }
        muteGroup.isMuted = true
    }

    func unmute() {
        guard hasController else { return }
        registeredVideos.values.forEach { $0.unmute() }
        muteGroup.isMuted = false
    }

    func toggleMute() {
        guard hasController else { return }
        if isMuted { unmute() } else { mute() }
    }

    // MARK: - State Updates from Videos

    func updatePlayingState(_ playing: Bool) {
        if !playGroup.isPlayingInitialized {
            playGroup.initializePlaying(playing)
        } else if isPlaying != playing {
            playGroup.isPlaying = playing
        }
    }

    func updateMutedState(_ muted: Bool) {
        if !muteGroup.isMutedInitialized {
            muteGroup.initializeMuted(muted)
        } else if isMuted != muted {
            muteGroup.isMuted = muted
        }
    }

    // MARK: - Group Sync

    private func setupGroupSync() {
        muteGroup.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.objectWillChange.send()
                let muted = self.muteGroup.isMuted
                if muted {
                    self.registeredVideos.values.forEach { $0.mute() }
                } else {
                    self.registeredVideos.values.forEach { $0.unmute() }
                }
            }
        }.store(in: &subscriptions)

        playGroup.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.objectWillChange.send()
                let playing = self.playGroup.isPlaying
                if playing {
                    self.registeredVideos.values.forEach { $0.play() }
                } else {
                    self.registeredVideos.values.forEach { $0.pause() }
                }
            }
        }.store(in: &subscriptions)
    }
}
