/* Copyright Airship and Contributors */

import Foundation
import Combine

@MainActor
class VideoGroupState: ObservableObject {
    @Published var isMuted: Bool = false
    @Published var isPlaying: Bool = false

    private(set) var isMutedInitialized: Bool = false
    private(set) var isPlayingInitialized: Bool = false

    func initializeMuted(_ muted: Bool) {
        guard !isMutedInitialized else { return }
        isMutedInitialized = true
        isMuted = muted
    }

    func initializePlaying(_ playing: Bool) {
        guard !isPlayingInitialized else { return }
        isPlayingInitialized = true
        isPlaying = playing
    }
}

@MainActor
class VideoGroups {
    private var muteGroups: [String: VideoGroupState]
    private var playGroups: [String: VideoGroupState]

    init(
        muteGroups: [String: VideoGroupState] = [:],
        playGroups: [String: VideoGroupState] = [:]
    ) {
        self.muteGroups = muteGroups
        self.playGroups = playGroups
    }

    func muteGroup(for id: String) -> VideoGroupState {
        if let existing = muteGroups[id] { return existing }
        let group = VideoGroupState()
        muteGroups[id] = group
        return group
    }

    func playGroup(for id: String) -> VideoGroupState {
        if let existing = playGroups[id] { return existing }
        let group = VideoGroupState()
        playGroups[id] = group
        return group
    }

    func copy() -> VideoGroups {
        VideoGroups(muteGroups: muteGroups, playGroups: playGroups)
    }
}
