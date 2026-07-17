/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Controller view for managing video playback state.
@MainActor
struct VideoController: View {
    private let info: ThomasViewInfo.VideoController
    private let constraints: ViewConstraints

    @EnvironmentObject private var environment: ThomasEnvironment
    @EnvironmentObject private var state: ThomasState
    @EnvironmentObject private var parentVideoState: VideoState

    init(
        info: ThomasViewInfo.VideoController,
        constraints: ViewConstraints
    ) {
        self.info = info
        self.constraints = constraints
    }

    var body: some View {
        Content(
            info: self.info,
            constraints: constraints,
            environment: environment,
            parentState: state,
            parentVideoState: parentVideoState
        )
    }

    @MainActor
    struct Content: View {
        @EnvironmentObject private var thomasEnvironment: ThomasEnvironment
        private let info: ThomasViewInfo.VideoController
        private let constraints: ViewConstraints

        @Environment(\.layoutState) private var layoutState

        @StateObject private var videoState: VideoState
        @StateObject private var state: ThomasState

        init(
            info: ThomasViewInfo.VideoController,
            constraints: ViewConstraints,
            environment: ThomasEnvironment,
            parentState: ThomasState,
            parentVideoState: VideoState
        ) {
            self.info = info
            self.constraints = constraints

            let videoGroups = parentVideoState.videoGroups.copy()

            let muteGroup = if let id = info.properties.muteGroup?.identifier {
                videoGroups.muteGroup(for: id)
            } else {
                VideoGroupState()
            }

            let playGroup = if let id = info.properties.playGroup?.identifier {
                videoGroups.playGroup(for: id)
            } else {
                VideoGroupState()
            }

            let videoState = VideoState(
                identifier: info.properties.identifier,
                videoScope: info.properties.videoScope,
                videoGroups: videoGroups,
                muteGroup: muteGroup,
                playGroup: playGroup
            )

            self._videoState = StateObject(wrappedValue: videoState)

            self._state = StateObject(
                wrappedValue: parentState.with(videoState: videoState)
            )
        }

        var body: some View {
            thomasEnvironment.viewFactory.createView(self.info.properties.view, constraints: constraints)
                .constraints(constraints)
                .thomasCommon(self.info)
                .environmentObject(self.videoState)
                .environmentObject(self.state)
                .accessibilityElement(children: .contain)
        }
    }
}
